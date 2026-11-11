"""SQLite v5->v6 deduction ledger regression and prior-data preservation."""
import pathlib
import re
import sqlite3
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCHEMA = (ROOT / 'assets/db/schema.sql').read_text(encoding='utf-8')


def statements(filename, array_name):
    code = (ROOT / 'lib/data' / filename).read_text(encoding='utf-8')
    match = re.search(r'const ' + array_name + r' = <String>\[(.*?)\];',
                      code, re.S)
    assert match, filename
    return [a or b for a, b in re.findall(
        r"r'''(.*?)'''|'([^']+)'", match.group(1), re.S)]


class DeductionMigrationTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.execute('PRAGMA foreign_keys=ON')
        self.db.executescript(SCHEMA)
        self.db.executemany('INSERT INTO companies(id,name) VALUES (?,?)',
                            [(1, 'C1'), (2, 'C2')])
        self.db.executemany(
            "INSERT INTO parties(id,company_id,full_name,type)"
            " VALUES (?,?,'Holder','COMPANY')",
            [(1,1),(2,1),(3,2),(4,2)])
        self.db.executemany(
            "INSERT INTO contracts(id,company_id,contract_no,title,"
            "employer_party_id,contractor_party_id,start_date,amount_rial)"
            " VALUES (?,?,?,'Project',?,?,'2026-11-01',5000000)",
            [(1,1,'A',1,2),(2,2,'B',3,4)])
        self.db.executemany(
            "INSERT INTO statements(id,contract_id,statement_no,"
            "statement_date,gross_rial,vat_rial,deductions_rial,status)"
            " VALUES (?,?,?,'2026-11-01',1000000,0,?,?)",
            [(1,1,'LEGACY',200000,'APPROVED'),
             (2,1,'CURRENT',100000,'APPROVED'),
             (3,2,'OTHER',0,'APPROVED')])
        self.db.execute("INSERT INTO receipts(id,contract_id,receipt_date,"
                        "amount_rial) VALUES(1,1,'2026-11-05',700000)")
        self.db.execute("INSERT INTO statement_receipt_allocations"
                        " VALUES (2,1,500000)")
        self.db.commit()
        for filename, variable in [
            ('expense_migration.dart','expenseV2Sql'),
            ('receipt_migration.dart','receiptV3Sql'),
            ('receivables_migration.dart','receivablesV4Sql'),
            ('boq_migration.dart','boqV5Sql'),
            ('deduction_migration.dart','deductionV6Sql'),
        ]:
            for sql in statements(filename, variable):
                self.db.execute(sql)
        self.db.execute('PRAGMA user_version=6')
        self.db.commit()

    def tearDown(self):
        self.db.close()

    def put_details(self, statement_id, values, new_total, reason):
        with self.db:
            old = self.db.execute('SELECT deductions_rial FROM statements '
                                  'WHERE id=?', (statement_id,)).fetchone()[0]
            old_rows = self.db.execute(
                'SELECT kind,amount_rial FROM statement_deduction_lines '
                'WHERE statement_id=? ORDER BY kind', (statement_id,)).fetchall()
            self.db.execute('DELETE FROM statement_deduction_lines '
                            'WHERE statement_id=?', (statement_id,))
            for kind, amount in values:
                self.db.execute(
                    'INSERT INTO statement_deduction_lines '
                    '(statement_id,kind,amount_rial,basis_ref) '
                    'VALUES (?,?,?,?)',
                    (statement_id,kind,amount,'BASIS-1405'))
            self.db.execute('UPDATE statements SET deductions_rial=? '
                            'WHERE id=?', (new_total,statement_id))
            self.db.execute(
                'INSERT INTO statement_deduction_audit'
                '(contract_id,statement_id,previous_rial,current_rial,'
                'before_json,after_json,reason)'
                ' VALUES(?,?,?,?,?,?,?)',
                (1,statement_id,old,new_total,str(old_rows),
                 str(values),reason))

    def test_original_deductions_preserved_and_unclassified(self):
        self.assertEqual(
            self.db.execute('SELECT deductions_rial FROM statements '
                            'WHERE id=1').fetchone(),(200000,))
        self.assertEqual(self.db.execute(
            'SELECT COUNT(*) FROM statement_deduction_lines').fetchone(),(0,))
        self.assertEqual(self.db.execute('PRAGMA user_version').fetchone(),(6,))
        self.assertEqual(self.db.execute('PRAGMA foreign_key_check').fetchall(),[])
        self.assertEqual(self.db.execute('PRAGMA integrity_check').fetchone(),('ok',))

    def test_classified_deductions_balance_and_history(self):
        self.put_details(2, [('insurance',150000),('retention',100000)],
                         250000,'تطبیق با مستند پیمان')
        self.assertEqual(
            self.db.execute('SELECT deductions_rial FROM statements '
                            'WHERE id=2').fetchone(),(250000,))
        self.assertEqual(
            self.db.execute('SELECT SUM(amount_rial) '
                            'FROM statement_deduction_lines '
                            'WHERE statement_id=2').fetchone(),(250000,))
        self.assertEqual(
            self.db.execute('SELECT previous_rial,current_rial '
                            'FROM statement_deduction_audit').fetchone(),
            (100000,250000))

    def test_manual_total_change_without_detail_is_blocked(self):
        self.put_details(2, [('insurance',150000),('retention',100000)],
                         250000,'سابقه آزمایشی')
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('UPDATE statements SET deductions_rial=249999 '
                            'WHERE id=2')
        self.db.rollback()
        self.assertEqual(
            self.db.execute('SELECT deductions_rial FROM statements '
                            'WHERE id=2').fetchone(),(250000,))

    def test_prohibit_excess_deduction_below_allocated_receipts(self):
        self.put_details(2, [('insurance',300000),('retention',100000)],
                         400000,'کنترل مبلغ وصول')
        with self.assertRaises(sqlite3.IntegrityError):
            self.put_details(2, [('insurance',600001)],600001,
                             'اصلاح غیرمجاز')
        self.assertEqual(
            self.db.execute('SELECT deductions_rial FROM statements '
                            'WHERE id=2').fetchone(),(400000,))
        self.assertEqual(
            self.db.execute('SELECT amount_rial '
                            'FROM statement_deduction_lines '
                            'WHERE statement_id=2 AND kind=?',
                            ('insurance',)).fetchone(), (300000,))
        self.assertEqual(self.db.execute(
            'SELECT COUNT(*) FROM statement_deduction_audit '
            'WHERE statement_id=2').fetchone(),(1,))

    def test_audit_is_immutable_and_prevents_statement_deletion(self):
        self.put_details(2, [('advance',100000)],100000,
                         'ثبت استهلاک پیش‌پرداخت')
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('UPDATE statement_deduction_audit '
                            'SET reason=?',( 'tampered',))
        self.db.rollback()
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('DELETE FROM statement_deduction_audit')
        self.db.rollback()
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('DELETE FROM statements WHERE id=2')
        self.db.rollback()

    def test_cross_contract_audit_and_invalid_line_rejected(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('INSERT INTO statement_deduction_audit'
                            '(contract_id,statement_id,previous_rial,current_rial,'
                            'before_json,after_json,reason)'
                            " VALUES(2,1,0,0,'[]','[]','invalid scope')")
        self.db.rollback()
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('INSERT INTO statement_deduction_lines '
                            '(statement_id,kind,amount_rial,basis_ref) '
                            "VALUES(1,'invalid',100,'Ref-1')")
        self.db.rollback()
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('INSERT INTO statement_deduction_lines '
                            '(statement_id,kind,amount_rial,basis_ref) '
                            "VALUES(1,'retention',100,'')")
        self.db.rollback()

    def test_wiring_for_real_upgrade_and_ui_is_present(self):
        store = (ROOT / 'lib/data/offline_store.dart').read_text(
            encoding='utf-8')
        self.assertIn('databaseVersion = 6',store)
        self.assertIn('upgradeDeductionDatabase(db, oldVersion, newVersion)',store)
        self.assertIn("'statement_deduction_audit'",store)
        screen = (ROOT / 'lib/screens/finance_screen.dart').read_text(
            encoding='utf-8')
        self.assertIn('StatementDeductionsScreen',screen)


if __name__ == '__main__':
    unittest.main()
