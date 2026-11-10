import pathlib
import re
import sqlite3
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCHEMA = (ROOT / "assets/db/schema.sql").read_text(encoding="utf-8")
MIGRATION = (ROOT / "lib/data/receivables_migration.dart").read_text(encoding="utf-8")
SQL = [next(value for value in match if value) for match in
       re.findall(r"r'''(.*?)'''|'(CREATE INDEX [^']+)'", MIGRATION, re.S)]


class ReceivableMigrationTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.db.execute("PRAGMA foreign_keys=ON")
        self.db.executescript(SCHEMA)
        # Simulate a v3 upgrade retaining old allocations.
        self.db.execute("ALTER TABLE receipts ADD COLUMN category_code TEXT")
        self.db.execute("INSERT INTO companies(id,name) VALUES (1,'Company')")
        self.db.execute("INSERT INTO companies(id,name) VALUES (2,'Other')")
        self.db.executemany(
            "INSERT INTO parties(id,company_id,full_name,type) VALUES (?,?,?,?)",
            [(1,1,'Employer','COMPANY'), (2,1,'Contractor','COMPANY'),
             (3,2,'Employer 2','COMPANY'), (4,2,'Contractor 2','COMPANY')])
        self.db.executemany("""
            INSERT INTO contracts(id,company_id,contract_no,title,
                 employer_party_id,contractor_party_id,start_date,amount_rial)
            VALUES (?,?,?,?,?,?,?,?)""",
            [(1,1,'1','A',1,2,'2026-11-01',100000),
             (2,2,'2','B',3,4,'2026-11-01',100000)])
        self.db.executemany("""
            INSERT INTO statements(id,contract_id,statement_no,statement_date,
                                   gross_rial,vat_rial,deductions_rial,status)
            VALUES (?,?,?,'2026-11-02',?,0,0,?)""",
            [(1,1,'S-1',1000,'APPROVED'),
             (2,2,'S-2',1000,'APPROVED'),
             (3,1,'S-3',1000,'SUBMITTED')])
        self.db.executemany("""
            INSERT INTO receipts(id,contract_id,receipt_date,amount_rial,category_code)
            VALUES (?,?,'2026-11-03',?,?)""",
            [(1,1,900,'statement_collection'),
             (2,2,900,'statement_collection'),
             (3,1,1000,'contract_advance'),
             (4,1,1000,None)])
        # This historical allocation will be preserved and labelled LEGACY.
        self.db.execute(
            "INSERT INTO statement_receipt_allocations VALUES (1,1,200)")
        for sql in SQL:
            self.db.execute(sql)

    def tearDown(self):
        self.db.close()

    def test_complete_v4_migration(self):
        self.assertEqual(len(SQL), 9)
        self.assertEqual(
            self.db.execute("SELECT action,amount_rial,note FROM "
                            "statement_receipt_audit").fetchone()[0:2],
            ('LEGACY',200))
        self.assertEqual(self.db.execute(
            "SELECT amount_rial FROM statement_receipt_allocations "
            "WHERE statement_id=1 AND receipt_id=1").fetchone(),(200,))
        self.assertEqual(self.db.execute("PRAGMA integrity_check").fetchone()[0], "ok")
        self.assertEqual(self.db.execute("PRAGMA foreign_key_check").fetchall(), [])

    def test_allocation_is_contract_scoped_and_cannot_overpay(self):
        self.db.execute(
            "UPDATE statement_receipt_allocations SET amount_rial=500 "
            "WHERE statement_id=1 AND receipt_id=1")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO statement_receipt_allocations VALUES(1,2,100)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO statement_receipt_allocations VALUES(1,3,100)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO statement_receipt_allocations VALUES(3,1,100)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE statement_receipt_allocations SET amount_rial=1001 WHERE statement_id=1 AND receipt_id=1")
        self.assertEqual(self.db.execute(
            "SELECT amount_rial FROM statement_receipt_allocations WHERE statement_id=1 AND receipt_id=1").fetchone(),(500,))

    def test_receipt_category_cannot_be_reclassified_while_linked(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE receipts SET category_code='contract_advance' WHERE id=1")
        self.assertEqual(self.db.execute(
            "SELECT category_code FROM receipts WHERE id=1").fetchone()[0],
            'statement_collection')
        self.db.execute("DELETE FROM statement_receipt_allocations WHERE statement_id=1 AND receipt_id=1")
        self.db.execute("UPDATE receipts SET category_code='contract_advance' WHERE id=1")

    def test_immutable_audit_after_cash_application(self):
        self.db.execute("""
            INSERT INTO statement_receipt_audit
              (contract_id,statement_id,receipt_id,action,amount_rial,note)
            VALUES(1,1,1,'LINK',50,'allocated')
        """)
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE statement_receipt_audit SET amount_rial=1 WHERE action='LINK'")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("DELETE FROM statement_receipt_audit WHERE action='LINK'")

    def test_reversal_changes_links_not_cash(self):
        before = self.db.execute("SELECT amount_rial FROM receipts WHERE id=1").fetchone()[0]
        self.db.execute("DELETE FROM statement_receipt_allocations WHERE statement_id=1 AND receipt_id=1")
        self.db.execute("""
            INSERT INTO statement_receipt_audit
            (contract_id,statement_id,receipt_id,action,amount_rial,note)
            VALUES(1,1,1,'UNLINK',200,'wrong assignment')
        """)
        after = self.db.execute("SELECT amount_rial FROM receipts WHERE id=1").fetchone()[0]
        self.assertEqual(before, after)
        self.assertEqual(self.db.execute(
            "SELECT COUNT(*) FROM statement_receipt_audit").fetchone()[0],2)


if __name__ == '__main__':
    unittest.main()
