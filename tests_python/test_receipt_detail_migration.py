"""Verify real v1->v2->v3 SQLite migrations and receipt constraints."""
import re
import sqlite3
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPENSE_MIGRATION = (ROOT / "lib/data/expense_migration.dart").read_text()
RECEIPT_MIGRATION = (ROOT / "lib/data/receipt_migration.dart").read_text()
CATALOG = (ROOT / "lib/finance/receipt_catalog.dart").read_text()

V2_PRE = [
    "ALTER TABLE expenses ADD COLUMN category_code TEXT",
    "ALTER TABLE expenses ADD COLUMN detail_title TEXT",
    "ALTER TABLE expenses ADD COLUMN counterparty_name TEXT",
    "CREATE INDEX idx_expenses_category_code ON expenses(category_code)",
]
V2_TRIGGERS = re.findall(r"r'''(.*?)'''", EXPENSE_MIGRATION, re.S)
V3_PRE = re.findall(r"^\s*'((?:ALTER TABLE|CREATE INDEX)[^']+)'", RECEIPT_MIGRATION, re.M)
V3_TRIGGERS = re.findall(r"r'''(.*?)'''", RECEIPT_MIGRATION, re.S)
CODES = re.findall(r"ReceiptCategory\('([a-z_]+)'", CATALOG)


class IncomeMigrationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        path = Path(self.tmp.name) / "db.sqlite"
        path.write_bytes((ROOT / "assets/db/seed.sqlite").read_bytes())
        self.db = sqlite3.connect(path)
        self.db.execute("PRAGMA foreign_keys=ON")
        self.assertEqual(
            self.db.execute("PRAGMA user_version").fetchone()[0], 1)
        comp = self.db.execute("INSERT INTO companies(name) VALUES ('Saba')").lastrowid
        a = self.db.execute(
            "INSERT INTO parties(company_id,full_name,type) VALUES (?,?,?)",
            (comp, "Municipality", "COMPANY")).lastrowid
        b = self.db.execute(
            "INSERT INTO parties(company_id,full_name,type) VALUES (?,?,?)",
            (comp, "Contractor", "COMPANY")).lastrowid
        self.contract = self.db.execute(
            """INSERT INTO contracts(company_id,contract_no,title,
               employer_party_id,contractor_party_id,start_date,amount_rial)
               VALUES (?,?,?,?,?,?,?,?)""",
            (comp, "M-1", "Municipality contract", a, b, "2026-11-09", 1000000)
        ).lastrowid
        self.legacy = self.db.execute(
            "INSERT INTO receipts(contract_id,receipt_date,amount_rial,memo) "
            "VALUES (?,?,?,?)", (self.contract, "2026-11-09", 100000, "Old deposit")
        ).lastrowid
        st = self.db.execute(
            "INSERT INTO statements(contract_id,statement_no,statement_date,gross_rial,status) "
            "VALUES (?,?,?,?,?)",
            (self.contract, "ST1", "2026-11-09", 80000, "APPROVED")
        ).lastrowid
        self.db.execute(
            "INSERT INTO statement_receipt_allocations(statement_id,receipt_id,amount_rial) "
            "VALUES (?,?,?)", (st, self.legacy, 50000)
        )
        self.db.commit()

    def tearDown(self):
        self.db.close()
        self.tmp.cleanup()

    def migrate2(self):
        self.assertEqual(len(V2_TRIGGERS), 2)
        with self.db:
            for sql in V2_PRE + V2_TRIGGERS:
                self.db.execute(sql)
            self.db.execute("PRAGMA user_version=2")

    def migrate3(self):
        self.assertEqual(len(V3_PRE), 5)
        self.assertEqual(len(V3_TRIGGERS), 2)
        with self.db:
            for sql in V3_PRE + V3_TRIGGERS:
                self.db.execute(sql)
            self.db.execute("PRAGMA user_version=3")

    def insert_receipt(self, code, payer, detail, method="TRANSFER", ref=""):
        return self.db.execute(
            """INSERT INTO receipts(contract_id,receipt_date,amount_rial,category_code,
                counterparty_name,detail_title,payment_method,reference_no)
                VALUES (?,?,?,?,?,?,?,?)""",
            (self.contract, "2026-11-09", 5000, code, payer, detail, method, ref))

    def test_original_rows_and_allocation_survive_both_upgrades(self):
        before = self.db.execute(
            "SELECT received_rial FROM v_contract_financial_summary WHERE contract_id=?",
            (self.contract,)
        ).fetchone()[0]
        self.migrate2()
        self.migrate3()
        current = self.db.execute(
            "SELECT amount_rial,memo,category_code,counterparty_name "
            "FROM receipts WHERE id=?", (self.legacy,)
        ).fetchone()
        self.assertEqual(current, (100000, "Old deposit", None, None))
        alloc = self.db.execute(
            "SELECT amount_rial FROM statement_receipt_allocations "
            "WHERE receipt_id=?", (self.legacy,)
        ).fetchone()[0]
        self.assertEqual(alloc, 50000)
        after = self.db.execute(
            "SELECT received_rial FROM v_contract_financial_summary WHERE contract_id=?",
            (self.contract,)
        ).fetchone()[0]
        self.assertEqual(before, after)
        self.assertEqual(self.db.execute("PRAGMA quick_check").fetchone()[0], "ok")
        self.assertEqual(self.db.execute("PRAGMA foreign_key_check").fetchall(), [])

    def test_v2_upgrade_preserves_old_receipts(self):
        self.migrate2()
        self.migrate3()
        self.assertEqual(self.db.execute("PRAGMA user_version").fetchone()[0], 3)
        self.db.execute(
            "UPDATE receipts SET memo='Updated legacy memo' WHERE id=?", (self.legacy,))
        self.assertEqual(self.db.execute(
            "SELECT memo FROM receipts WHERE id=?", (self.legacy,)
        ).fetchone()[0], "Updated legacy memo")

    def test_new_receipts_require_payer_category_and_payment_method(self):
        self.migrate2()
        self.migrate3()
        for category, payer, detail, method in [
            (None, "Municipality", "ST1", "TRANSFER"),
            ("bad", "Municipality", "ST1", "TRANSFER"),
            ("on_account", "", "November", "TRANSFER"),
            ("on_account", "Municipality", "", None),
            ("on_account", "Municipality", "", "UNKNOWN"),
        ]:
            with self.subTest(category=category, payer=payer, method=method):
                with self.assertRaises(sqlite3.IntegrityError):
                    self.insert_receipt(category, payer, detail, method)

    def test_statement_receipt_requires_document_reference(self):
        self.migrate2()
        self.migrate3()
        with self.assertRaises(sqlite3.IntegrityError):
            self.insert_receipt("statement_collection", "Municipality", "")
        row = self.insert_receipt(
            "statement_collection", "Municipality", "ST2",
            ref="IBAN-ref-256").lastrowid
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute(
                "UPDATE receipts SET detail_title='' WHERE id=?", (row,))
        self.assertEqual(self.db.execute(
            "SELECT reference_no FROM receipts WHERE id=?", (row,)
        ).fetchone()[0], "IBAN-ref-256")

    def test_codes_match_catalog_and_other_requires_detail(self):
        self.migrate2()
        self.migrate3()
        self.assertEqual(len(CODES), len(set(CODES)))
        self.assertGreaterEqual(len(CODES), 9)
        for code in CODES:
            with self.subTest(code=code):
                self.insert_receipt(code, "Municipality", "Specific description")
        with self.assertRaises(sqlite3.IntegrityError):
            self.insert_receipt("other", "Municipality", "")

    def test_net_statement_is_not_receipt(self):
        self.migrate2()
        self.migrate3()
        self.db.execute(
            "INSERT INTO statements(contract_id,statement_no,statement_date,gross_rial,"
            "vat_rial,deductions_rial,status) VALUES (?,?,?,?,?,?,?)",
            (self.contract, "ST2", "2026-11-09", 120000, 12000, 17000, "APPROVED")
        )
        net = self.db.execute(
            "SELECT approved_net_payable_rial FROM v_contract_financial_summary "
            "WHERE contract_id=?", (self.contract,)
        ).fetchone()[0]
        self.assertEqual(net, 80000 + 120000 + 12000 - 17000)
        received = self.db.execute(
            "SELECT received_rial FROM v_contract_financial_summary WHERE contract_id=?",
            (self.contract,)
        ).fetchone()[0]
        self.assertEqual(received, 100000)


if __name__ == "__main__":
    unittest.main()
