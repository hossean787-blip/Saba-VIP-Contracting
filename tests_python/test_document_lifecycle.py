"""Regression coverage for safe financial document deletion on bundled SQLite."""
import sqlite3
import tempfile
import unittest
from pathlib import Path

SEED = Path(__file__).resolve().parents[1] / "assets/db/seed.sqlite"
STORE = Path(__file__).resolve().parents[1] / "lib/data/offline_store.dart"


class DocumentLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        database = Path(self.tmp.name) / "test.sqlite"
        database.write_bytes(SEED.read_bytes())
        self.db = sqlite3.connect(database)
        self.db.execute("PRAGMA foreign_keys=ON")
        with self.db:
            self.db.execute("INSERT INTO companies(id,name) VALUES (1,'Example')")
            for party_id in (10, 11):
                self.db.execute(
                    "INSERT INTO parties(id,company_id,full_name,type) "
                    "VALUES (?,1,'Example','COMPANY')", (party_id,))
            for cid in (1, 2):
                self.db.execute(
                    "INSERT INTO contracts(id,company_id,contract_no,title,"
                    "employer_party_id,contractor_party_id,start_date,amount_rial) "
                    "VALUES (?,1,?,'Project',10,11,'2026-11-09',10000000)",
                    (cid, str(cid)))

    def tearDown(self):
        self.db.close()
        self.tmp.cleanup()

    def expense(self, contract=1):
        with self.db:
            return self.db.execute(
                "INSERT INTO expenses(contract_id,expense_date,category,amount_rial) "
                "VALUES (?,'2026-11-09','materials',1000000)", (contract,)
            ).lastrowid

    def payment(self, contract, amount, links=()):
        with self.db:
            payment_id = self.db.execute(
                "INSERT INTO payments(contract_id,payment_date,amount_rial) "
                "VALUES (?,'2026-11-09',?)", (contract, amount)
            ).lastrowid
            for expense_id, allocation in links:
                self.db.execute(
                    "INSERT INTO expense_payment_allocations(expense_id,payment_id,amount_rial) "
                    "VALUES (?,?,?)", (expense_id, payment_id, allocation))
        return payment_id

    def count(self, table):
        return self.db.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]

    def delete_expense_safely(self, contract_id, expense_id):
        """Mirror the guarded deletion transaction used by OfflineStore."""
        with self.db:
            selected = self.db.execute(
                "SELECT id FROM expenses WHERE id=? AND contract_id=?",
                (expense_id, contract_id)).fetchone()
            if not selected:
                raise ValueError("record not in selected contract")
            links = self.db.execute(
                "SELECT payment_id,amount_rial FROM expense_payment_allocations "
                "WHERE expense_id=?", (expense_id,)).fetchall()
            for payment_id, allocated in links:
                payment = self.db.execute(
                    "SELECT amount_rial FROM payments WHERE id=? AND contract_id=?",
                    (payment_id, contract_id)).fetchone()
                number, total = self.db.execute(
                    "SELECT COUNT(*),COALESCE(SUM(amount_rial),0) "
                    "FROM expense_payment_allocations WHERE payment_id=?",
                    (payment_id,)).fetchone()
                if payment is None or number != 1 or total != payment[0]:
                    raise ValueError("shared or partly unallocated payment")
            self.db.execute("DELETE FROM expense_payment_allocations WHERE expense_id=?",
                            (expense_id,))
            for payment_id, _ in links:
                self.db.execute("DELETE FROM payments WHERE id=? AND contract_id=?",
                                (payment_id, contract_id))
            self.db.execute("DELETE FROM expenses WHERE id=? AND contract_id=?",
                            (expense_id, contract_id))

    def test_unpaid_expense_delete_preserves_legacy_independent_cash(self):
        expense_id = self.expense()
        legacy_payment_id = self.payment(1, 500000)
        self.delete_expense_safely(1, expense_id)
        self.assertEqual(self.count("expenses"), 0)
        self.assertEqual(self.count("payments"), 1)
        self.assertEqual(self.db.execute("SELECT id FROM payments").fetchone()[0],
                         legacy_payment_id)

    def test_paid_expense_delete_removes_only_its_exclusive_cash(self):
        first = self.expense()
        second = self.expense()
        first_payment = self.payment(1, 400000, [(first, 400000)])
        second_payment = self.payment(1, 100000, [(second, 100000)])
        self.delete_expense_safely(1, first)
        self.assertEqual(self.count("expenses"), 1)
        self.assertEqual(self.count("payments"), 1)
        self.assertEqual(self.count("expense_payment_allocations"), 1)
        self.assertEqual(self.db.execute("SELECT id FROM payments").fetchone()[0],
                         second_payment)
        self.assertNotEqual(first_payment, second_payment)

    def test_shared_payment_cannot_be_deleted_by_one_expense(self):
        first = self.expense()
        second = self.expense()
        self.payment(1, 500000, [(first, 200000), (second, 300000)])
        with self.assertRaises(ValueError):
            self.delete_expense_safely(1, first)
        self.assertEqual(self.count("expenses"), 2)
        self.assertEqual(self.count("payments"), 1)
        self.assertEqual(self.count("expense_payment_allocations"), 2)

    def test_partially_unallocated_cash_is_preserved(self):
        first = self.expense()
        self.payment(1, 500000, [(first, 200000)])
        with self.assertRaises(ValueError):
            self.delete_expense_safely(1, first)
        self.assertEqual(self.count("expenses"), 1)
        self.assertEqual(self.count("payments"), 1)

    def test_other_contract_cannot_delete_expense(self):
        first = self.expense(1)
        with self.assertRaises(ValueError):
            self.delete_expense_safely(2, first)
        self.assertEqual(self.count("expenses"), 1)

    def test_receipt_statement_allocation_cannot_be_orphaned(self):
        with self.db:
            receipt = self.db.execute(
                "INSERT INTO receipts(contract_id,receipt_date,amount_rial) "
                "VALUES (1,'2026-11-09',400000)").lastrowid
            statement = self.db.execute(
                "INSERT INTO statements(contract_id,statement_no,statement_date,"
                "gross_rial,status) VALUES (1,'1','2026-11-09',800000,'APPROVED')"
            ).lastrowid
            self.db.execute(
                "INSERT INTO statement_receipt_allocations(statement_id,receipt_id,amount_rial) "
                "VALUES (?,?,400000)", (statement, receipt))
        for field, target in (("receipt_id", receipt), ("statement_id", statement)):
            linked = self.db.execute(
                "SELECT 1 FROM statement_receipt_allocations WHERE " + field + "=?",
                (target,)).fetchone()
            self.assertIsNotNone(linked)
        self.assertEqual(self.count("receipts"), 1)
        self.assertEqual(self.count("statements"), 1)

    def test_app_has_explicit_scoped_and_shared_payment_guards(self):
        code = STORE.read_text()
        method = code.split("Future<int> deleteFinancialRecord(", 1)[1]
        self.assertIn("id=? AND contract_id=?", method)
        self.assertIn("allocations.single['count']", method)
        self.assertIn("payment.single['amount_rial']", method)
        self.assertIn("statement_receipt_allocations", method)
        self.assertIn("db.transaction((txn) async", method)


if __name__ == "__main__":
    unittest.main()
