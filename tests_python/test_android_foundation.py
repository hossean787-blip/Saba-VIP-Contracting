import pathlib
import sqlite3
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SEED = ROOT / 'assets/db/seed.sqlite'

class AppFoundationTest(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.execute('PRAGMA foreign_keys=ON')
        self.db.executescript((ROOT / 'assets/db/schema.sql').read_text(encoding='utf-8'))
        self.db.execute("INSERT INTO companies(id,name) VALUES (1,'شرکت آزمایشی')")
        self.db.executemany("INSERT INTO parties(id,company_id,full_name,type) VALUES (?,?,?,?)",[(1,1,'کارفرما','COMPANY'),(2,1,'پیمانکار','COMPANY')])
        self.db.execute("INSERT INTO contracts(id,company_id,contract_no,title,employer_party_id,contractor_party_id,start_date,amount_rial) VALUES (1,1,'A-1','نقشه برداری',1,2,'2026-11-08',500000000)")
    def tearDown(self): self.db.close()

    def test_seed_valid_and_empty(self):
        c = sqlite3.connect(SEED)
        try:
            self.assertEqual(c.execute('pragma integrity_check').fetchone()[0], 'ok')
            self.assertEqual(c.execute('pragma user_version').fetchone()[0], 1)
            self.assertEqual(c.execute('select count(*) from companies').fetchone()[0],0)
            self.assertEqual(len(c.execute("select name from sqlite_master where type='table'").fetchall()),12)
        finally: c.close()

    def test_dashboard_real_aggregation(self):
        self.db.execute("INSERT INTO expenses(contract_id,expense_date,category,amount_rial) VALUES(1,'2026-11-08','دستمزد',130000000)")
        self.db.execute("INSERT INTO payments(contract_id,payment_date,amount_rial) VALUES(1,'2026-11-08',60000000)")
        self.db.execute("INSERT INTO receipts(contract_id,receipt_date,amount_rial) VALUES(1,'2026-11-08',85000000)")
        self.db.execute("INSERT INTO statements(contract_id,statement_no,statement_date,gross_rial,status) VALUES(1,'S1','2026-11-08',200000000,'APPROVED')")
        summary=self.db.execute('select cost_rial,paid_rial,received_rial,approved_work_rial,provisional_margin_rial,cash_flow_rial from v_contract_financial_summary where contract_id=1').fetchone()
        self.assertEqual(summary,(130000000,60000000,85000000,200000000,70000000,25000000))

    def test_only_approved_statement_affects_estimate(self):
        self.db.execute("INSERT INTO statements(contract_id,statement_no,statement_date,gross_rial,status) VALUES(1,'S1','2026-11-08',200000000,'DRAFT')")
        self.assertEqual(self.db.execute('select approved_work_rial from v_contract_financial_summary').fetchone()[0],0)

    def test_duplicate_contract_rejected(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO contracts(company_id,contract_no,title,employer_party_id,contractor_party_id,start_date,amount_rial) VALUES(1,'A-1','ب',1,2,'2026-11-08',100)")

    def test_foreign_keys_prevent_orphan_expense(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO expenses(contract_id,expense_date,category,amount_rial) VALUES(8123,'2026-11-08','مصالح',500)")

    def test_no_external_server_dependency_in_pubspec(self):
        pubspec=(ROOT/'pubspec.yaml').read_text()
        for word in ['firebase_core:', 'supabase_flutter:', 'http:', 'dio:']:
            self.assertNotIn(word,pubspec)
        self.assertIn('sqflite:', pubspec)

    def test_source_uses_foreign_keys(self):
        source=(ROOT/'lib/data/offline_store.dart').read_text()
        self.assertIn("PRAGMA foreign_keys=ON",source)
        self.assertIn('db.transaction(',source)

    def test_source_never_overwrites_existing_db(self):
        source=(ROOT/'lib/data/offline_store.dart').read_text()
        self.assertIn('if (!await databaseExists(dbPath))',source)

    def test_rows_bound_to_contract(self):
        src=(ROOT/'lib/data/offline_store.dart').read_text()
        self.assertIn("where: 'contract_id=?'",src)

if __name__ == '__main__':unittest.main(verbosity=2)
