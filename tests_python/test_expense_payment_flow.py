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

    def test_exact_legacy_rial_remainder_can_be_settled(self):
        eid = self.expense()
        self.pay(eid, 1, 999999)
        self.pay(eid, 1, 1)
        self.assertEqual(self.allocated(eid), 1000000)
        with self.assertRaises(sqlite3.IntegrityError):
            self.pay(eid, 1, 1)
        self.assertEqual(self.summary(), (1000000, 1000000))

    def test_allocation_updates_reject_overpayment_and_cross_contract(self):
        eid = self.expense()
        self.pay(eid, 1, 400000)
        other = self.db.execute(
            "INSERT INTO payments(contract_id,payment_date,amount_rial) "
            "VALUES (2,'2026-11-09',400000)").lastrowid
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE expense_payment_allocations SET amount_rial=1000001")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE expense_payment_allocations SET payment_id=?", (other,))
        self.assertEqual(self.allocated(eid), 400000)

    def test_allocated_parent_amount_and_contract_cannot_invalidate_links(self):
        eid = self.expense()
        self.pay(eid, 1, 400000)
        for table in ['expenses', 'payments']:
            for assignment in ['amount_rial=399999', 'contract_id=2']:
                with self.subTest(table=table, assignment=assignment):
                    with self.assertRaises(sqlite3.IntegrityError):
                        self.db.execute(f"UPDATE {table} SET {assignment}")
        self.assertEqual(self.allocated(eid), 400000)
        self.assertEqual(self.summary(), (1000000, 400000))

    def test_exact_report_queries_keep_allocations_separate_from_cash(self):
        import re
        source = (SEED.parents[2] / 'lib/data/offline_store.dart').read_text()
        queries = re.findall(r"r\'\'\'(.*?)\'\'\'", source, re.S)
        expense_query = next(q for q in queries if 'AS allocated_paid_rial' in q)
        link_query = next(q for q in queries if 'SELECT a.payment_id,a.expense_id' in q)
        eid = self.expense()
        self.pay(eid, 1, 400000)
        self.db.row_factory = sqlite3.Row
        expense = dict(self.db.execute(expense_query, (1,)).fetchone())
        self.assertEqual(expense['allocated_paid_rial'], 400000)
        self.assertEqual(expense['amount_rial'] - expense['allocated_paid_rial'], 600000)
        links = [dict(row) for row in self.db.execute(link_query, (1, 1))]
        self.assertEqual([(row['expense_id'], row['amount_rial']) for row in links], [(eid, 400000)])
        self.assertEqual(list(self.db.execute(link_query, (2, 2))), [])


if __name__ == '__main__':
    unittest.main()
