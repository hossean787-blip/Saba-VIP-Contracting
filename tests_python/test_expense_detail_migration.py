"""Execute the exact additive v2 migration SQL against a copy of the v1 seed."""
import re
import sqlite3
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SQL=re.findall(r"r'''(.*?)'''",(ROOT/'lib/data/expense_migration.dart').read_text(),re.S)
CODES=re.findall(r"ExpenseCategory\('([a-z_]+)'",(ROOT/'lib/finance/expense_catalog.dart').read_text())

class DetailUpgradeTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        dbpath=Path(self.tmp.name)/'store.sqlite'
        dbpath.write_bytes((ROOT/'assets/db/seed.sqlite').read_bytes())
        self.db=sqlite3.connect(dbpath)
        self.db.execute('PRAGMA foreign_keys=ON')
        self.assertEqual(self.db.execute('PRAGMA user_version').fetchone()[0],1)
        comp=self.db.execute("INSERT INTO companies(name) VALUES('شرکت')").lastrowid
        a=self.db.execute("INSERT INTO parties(company_id,full_name,type) VALUES(?,?,?)",(comp,'کارفرما','COMPANY')).lastrowid
        b=self.db.execute("INSERT INTO parties(company_id,full_name,type) VALUES(?,?,?)",(comp,'پیمانکار','COMPANY')).lastrowid
        self.contract=self.db.execute("""INSERT INTO contracts(company_id,contract_no,title,
           employer_party_id,contractor_party_id,start_date,amount_rial) VALUES(?,?,?,?,?,?,?)""",
           (comp,'CT-1','قرارداد',a,b,'2026-11-09',1000000)).lastrowid
        self.old=self.db.execute("""INSERT INTO expenses(contract_id,expense_date,category,amount_rial,memo)
           VALUES (?,?,?,?,?)""",(self.contract,'2026-11-09','حقوق قدیمی',250000,'قبل ارتقا')).lastrowid
        self.db.commit()
    def tearDown(self):
        self.db.close()
        self.tmp.cleanup()
    def migrate(self):
        self.assertEqual(len(SQL),6)
        with self.db:
            for sql in SQL: self.db.execute(sql)
            self.db.execute('PRAGMA user_version=2')
    def add(self,cat,detail='',owner=''):
        return self.db.execute("""INSERT INTO expenses(contract_id,expense_date,category,amount_rial,
            category_code,detail_title,counterparty_name) VALUES(?,?,?,?,?,?,?)""",
            (self.contract,'2026-11-09',cat,5000,cat,detail,owner))
    def test_legacy_rows_preserved(self):
        before=self.db.execute("SELECT cost_rial FROM v_contract_financial_summary WHERE contract_id=?",(self.contract,)).fetchone()[0]
        self.migrate()
        row=self.db.execute("SELECT amount_rial,memo,category_code,detail_title FROM expenses WHERE id=?",(self.old,)).fetchone()
        self.assertEqual(row,(250000,'قبل ارتقا',None,None))
        after=self.db.execute("SELECT cost_rial FROM v_contract_financial_summary WHERE contract_id=?",(self.contract,)).fetchone()[0]
        self.assertEqual(before,after)
        self.assertEqual(self.db.execute('PRAGMA foreign_key_check').fetchall(),[])
        self.assertEqual(self.db.execute('PRAGMA quick_check').fetchone()[0],'ok')
    def test_salary_requires_named_person(self):
        self.migrate()
        with self.assertRaises(sqlite3.IntegrityError): self.add('salary',owner='شرکت')
        self.add('salary',detail='شخص مشخص')
    def test_rental_requires_equipment_or_owner(self):
        self.migrate()
        with self.assertRaises(sqlite3.IntegrityError): self.add('equipment_rental')
        self.add('equipment_rental',detail='تجهیز')
        self.add('equipment_rental',owner='مالک تجهیز')
    def test_codes_align_and_unknown_rejected(self):
        self.migrate()
        self.assertEqual(len(CODES),len(set(CODES)))
        self.assertGreaterEqual(len(CODES),15)
        for code in CODES: self.add(code,detail='شرح')
        with self.assertRaises(sqlite3.IntegrityError): self.add('unrecognized',detail='شرح')
    def test_required_categories_validate_and_edits_protected(self):
        self.migrate()
        for code in ['day_labor','materials','equipment_purchase','subcontract','insurance','tax','utilities','permits','other']:
            with self.subTest(code=code):
                with self.assertRaises(sqlite3.IntegrityError): self.add(code,owner='پرداخت به شخص')
        row=self.add('salary',detail='علی').lastrowid
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE expenses SET detail_title='' WHERE id=?",(row,))
    def test_old_expense_update_still_works(self):
        self.migrate()
        self.db.execute("UPDATE expenses SET memo=? WHERE id=?",('اصلاح شرح',self.old))
        self.assertEqual(self.db.execute("SELECT category_code FROM expenses WHERE id=?",(self.old,)).fetchone()[0],None)
