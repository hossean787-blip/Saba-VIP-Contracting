"""Verify initial and later expense payments on the actual bundled SQLite schema."""
import sqlite3
import tempfile
import unittest
from pathlib import Path

SEED = Path(__file__).resolve().parents[1] / 'assets/db/seed.sqlite'


class ExpenseSettlementTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        path = Path(self.tmp.name) / 'test.db'
        path.write_bytes(SEED.read_bytes())
        self.db = sqlite3.connect(path)
        self.db.execute('PRAGMA foreign_keys=ON')
        self.db.execute("INSERT INTO companies(id,name) VALUES(1,'Saba')")
        for i in [10, 11]:
            self.db.execute(
                "INSERT INTO parties(id,company_id,full_name,type) VALUES(?,1,'P','COMPANY')", (i,))
        for i in [1, 2]:
            self.db.execute(
                "INSERT INTO contracts(id,company_id,contract_no,title,"
                "employer_party_id,contractor_party_id,start_date,amount_rial) "
                "VALUES (?,1,?,'Job',10,11,'2026-11-09',10000000)", (i, str(i)))
        self.db.commit()

    def tearDown(self):
        self.db.close()
        self.tmp.cleanup()

    def expense(self):
        with self.db:
            return self.db.execute(
                "INSERT INTO expenses(contract_id,expense_date,category,amount_rial) "
                "VALUES (1,'2026-11-09','materials',1000000)").lastrowid

    def pay(self, eid, cid, amount):
        with self.db:
            pid = self.db.execute(
                "INSERT INTO payments(contract_id,payment_date,amount_rial) "
                "VALUES (?,'2026-11-09',?)", (cid, amount)).lastrowid
            self.db.execute(
                "INSERT INTO expense_payment_allocations(expense_id,payment_id,amount_rial) "
                "VALUES (?,?,?)", (eid, pid, amount))

    def allocated(self, eid):
        return self.db.execute(
            "SELECT COALESCE(SUM(amount_rial),0) FROM expense_payment_allocations "
            "WHERE expense_id=?", (eid,)).fetchone()[0]

    def summary(self):
        return self.db.execute(
            "SELECT cost_rial, paid_rial FROM v_contract_financial_summary "
            "WHERE contract_id=1").fetchone()

    def test_unpaid_only_accrues_expense(self):
        eid = self.expense()
        self.assertEqual(self.allocated(eid), 0)
        self.assertEqual(self.summary(), (1000000, 0))

    def test_full_payment_no_double_counting(self):
        eid = self.expense()
        self.pay(eid, 1, 1000000)
        self.assertEqual(self.allocated(eid), 1000000)
        self.assertEqual(self.summary(), (1000000, 1000000))

    def test_partial_then_remaining_payment(self):
        eid = self.expense()
        self.pay(eid, 1, 400000)
        self.assertEqual(1000000 - self.allocated(eid), 600000)
        self.pay(eid, 1, 600000)
        self.assertEqual(1000000 - self.allocated(eid), 0)
        self.assertEqual(self.summary(), (1000000, 1000000))

    def test_overpayment_rolls_back_payment(self):
        eid = self.expense()
        self.pay(eid, 1, 900000)
        with self.assertRaises(sqlite3.IntegrityError):
            self.pay(eid, 1, 200000)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM payments').fetchone()[0], 1)
        self.assertEqual(self.allocated(eid), 900000)

    def test_other_contract_cannot_allocate_payment(self):
        eid = self.expense()
        with self.assertRaises(sqlite3.IntegrityError):
            self.pay(eid, 2, 100000)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM payments').fetchone()[0], 0)

    def test_unallocated_legacy_payment_does_not_settle_expense(self):
        eid = self.expense()
        self.db.execute(
            "INSERT INTO payments(contract_id,payment_date,amount_rial) "
            "VALUES (1,'2026-11-09',500000)")
        self.assertEqual(self.allocated(eid), 0)


if __name__ == '__main__':
    unittest.main()
