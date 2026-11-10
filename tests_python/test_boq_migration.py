import pathlib
import re
import sqlite3
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCHEMA = (ROOT / 'assets/db/schema.sql').read_text(encoding='utf-8')


def migration(filename, list_name):
    text = (ROOT / 'lib/data' / filename).read_text(encoding='utf-8')
    found = re.search(r'const ' + list_name + r' = <String>\[(.*?)\];',
                      text, re.S)
    assert found, (filename, list_name)
    return [left if left else right for left, right in
            re.findall(r"r'''(.*?)'''|'([^']+)'", found.group(1), re.S)]


class BoqUpgradeTest(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.execute('PRAGMA foreign_keys=ON')
        self.db.executescript(SCHEMA)
        self.db.execute("INSERT INTO companies(id,name) VALUES(1,'One')")
        self.db.execute("INSERT INTO companies(id,name) VALUES(2,'Two')")
        self.db.executemany(
            "INSERT INTO parties(id,company_id,full_name,type) "
            "VALUES(?,?,?,'COMPANY')",
            [(1, 1, 'Employer'), (2, 1, 'Contractor'),
             (3, 2, 'Employer2'), (4, 2, 'Contractor2')])
        self.db.executemany(
            "INSERT INTO contracts(id,company_id,contract_no,title,"
            "employer_party_id,contractor_party_id,start_date,amount_rial) "
            "VALUES(?,?,?,?,?,?,'2026-11-01',10000000)",
            [(1,1,'C1','First',1,2),(2,2,'C2','Second',3,4)])
        for sql in migration('expense_migration.dart', 'expenseV2Sql'):
            self.db.execute(sql)
        for sql in migration('receipt_migration.dart', 'receiptV3Sql'):
            self.db.execute(sql)
        # Real pre-upgrade data must survive v4 and v5 in-place.
        self.db.execute("INSERT INTO expenses(contract_id,expense_date,"
                        "category,amount_rial) VALUES(1,'2026-11-01','labor',20000)")
        self.db.execute("INSERT INTO statements(id,contract_id,statement_no,"
                        "statement_date,gross_rial,status) "
                        "VALUES(1,1,'S-OLD','2026-11-01',100000,'APPROVED')")
        self.db.execute("INSERT INTO receipts(id,contract_id,receipt_date,"
                        "amount_rial,category_code,detail_title,"
                        "counterparty_name,payment_method) "
                        "VALUES(1,1,'2026-11-01',50000,'statement_collection',"
                        "'S-OLD','Employer','TRANSFER')")
        self.db.execute("INSERT INTO statement_receipt_allocations "
                        "VALUES (1,1,50000)")
        for sql in migration('receivables_migration.dart', 'receivablesV4Sql'):
            self.db.execute(sql)
        for sql in migration('boq_migration.dart', 'boqV5Sql'):
            self.db.execute(sql)
        self.db.execute('PRAGMA user_version=5')

    def tearDown(self):
        self.db.close()

    def make_item(self, contract_id=1, code='101'):
        return self.db.execute(
            "INSERT INTO boq_items(contract_id,item_code,title,unit,"
            "price_source,planned_quantity_milli,unit_price_rial,coefficient_bp) "
            "VALUES(?,?,'Concrete','m3','Year 1404',20000,100000,10000)",
            (contract_id, code)).lastrowid

    def measure(self, item_id, quantity, contract_id=1):
        return self.db.execute(
            "INSERT INTO boq_measurements(contract_id,item_id,quantity_milli,"
            "measured_at,document_ref,note) "
            "VALUES(?,?,?,'2026-11-09','M-001','Recorded')",
            (contract_id, item_id, quantity)).lastrowid

    def test_upgrade_preserves_receipts_and_legacy_allocations(self):
        self.assertEqual(
            self.db.execute("SELECT amount_rial FROM expenses").fetchone(),
            (20000,))
        self.assertEqual(
            self.db.execute("SELECT amount_rial FROM "
                            "statement_receipt_allocations").fetchone(), (50000,))
        self.assertEqual(
            self.db.execute("SELECT action FROM statement_receipt_audit")
            .fetchone(), ('LEGACY',))
        self.assertEqual(
            self.db.execute("PRAGMA integrity_check").fetchone(), ('ok',))
        self.assertEqual(
            self.db.execute("PRAGMA foreign_key_check").fetchall(), [])
        self.assertEqual(
            self.db.execute("PRAGMA user_version").fetchone(), (5,))

    def test_measurement_is_scoped_and_append_only(self):
        item = self.make_item()
        with self.assertRaises(sqlite3.IntegrityError):
            self.measure(item, 1000, contract_id=2)
        measurement = self.measure(item, 3000)
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE boq_measurements SET quantity_milli=9000 "
                            "WHERE id=?", (measurement,))
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("DELETE FROM boq_measurements WHERE id=?",
                            (measurement,))
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE boq_items SET unit_price_rial=80000 "
                            "WHERE id=?", (item,))
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("DELETE FROM boq_items WHERE id=?", (item,))

    def test_reversal_is_additive_and_cannot_make_cumulative_negative(self):
        item = self.make_item()
        self.measure(item, 3000)
        self.measure(item, -1000)
        with self.assertRaises(sqlite3.IntegrityError):
            self.measure(item, -2001)
        total = self.db.execute(
            "SELECT SUM(quantity_milli) FROM boq_measurements "
            "WHERE item_id=?", (item,)).fetchone()[0]
        self.assertEqual(total, 2000)

    def test_billed_measurements_cannot_relink_and_statement_gross_locked(self):
        item = self.make_item()
        measurement = self.measure(item, 2000)
        self.db.execute("INSERT INTO statements(id,contract_id,statement_no,"
                        "statement_date,gross_rial,status) "
                        "VALUES(10,1,'S-NEW','2026-11-10',200000,'DRAFT')")
        self.db.execute("INSERT INTO boq_statement_lines "
                        "(statement_id,item_id,quantity_milli,unit_price_rial,"
                        "coefficient_bp,line_amount_rial) "
                        "VALUES(10,?,2000,100000,10000,200000)", (item,))
        self.db.execute("UPDATE boq_measurements SET statement_id=10 "
                        "WHERE id=?", (measurement,))
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE boq_measurements SET statement_id=NULL "
                            "WHERE id=?", (measurement,))
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE statements SET gross_rial=210000 WHERE id=10")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("DELETE FROM statements WHERE id=10")
        self.db.execute("UPDATE statements SET vat_rial=20000 WHERE id=10")
        self.db.execute("UPDATE statements SET status='APPROVED' WHERE id=10")
        self.assertEqual(self.db.execute(
            "SELECT status,vat_rial FROM statements WHERE id=10").fetchone(),
            ('APPROVED',20000))

    def test_cross_contract_boq_statement_line_rejected(self):
        item = self.make_item(contract_id=2,code='SECOND')
        self.db.execute("INSERT INTO statements(id,contract_id,statement_no,"
                        "statement_date,gross_rial,status) "
                        "VALUES(11,1,'S-MIX','2026-11-10',100000,'DRAFT')")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO boq_statement_lines "
                            "(statement_id,item_id,quantity_milli,"
                            "unit_price_rial,coefficient_bp,line_amount_rial) "
                            "VALUES(11,?,1000,100000,10000,100000)", (item,))

    def test_duplicate_code_is_contract_scoped(self):
        self.make_item(contract_id=1,code='A')
        with self.assertRaises(sqlite3.IntegrityError):
            self.make_item(contract_id=1,code='A')
        self.make_item(contract_id=2,code='A')

    def test_new_v5_wiring_and_old_v4_repair_are_present(self):
        store = (ROOT / 'lib/data/offline_store.dart').read_text(
            encoding='utf-8')
        self.assertIn('databaseVersion = 5', store)
        self.assertIn('upgradeReceivablesDatabase(db, oldVersion, newVersion)',store)
        self.assertIn('upgradeBoqDatabase(db, oldVersion, newVersion)',store)
        self.assertIn("'statement_receipt_audit'",store)
        self.assertIn("'boq_statement_lines'",store)


if __name__ == '__main__':
    unittest.main()
