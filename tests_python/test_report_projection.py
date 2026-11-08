"""Independent SQLite acceptance checks for v0.2 report projection.
These tests exercise the SQL schema and monetary semantics; they do not execute Dart.
"""
import sqlite3
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class ReportProjectionTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.execute('PRAGMA foreign_keys=ON')
        self.db.executescript((ROOT / 'assets/db/schema.sql').read_text(encoding='utf-8'))
        self.db.execute("INSERT INTO companies(id,name) VALUES(1,'شرکت الف'),(2,'شرکت ب')")
        self.db.executemany('INSERT INTO parties(id,company_id,full_name,type) VALUES(?,?,?,?)', [
            (1,1,'کارفرما اول','COMPANY'),(2,1,'پیمانکار اول','COMPANY'),
            (3,2,'کارفرما دوم','COMPANY'),(4,2,'پیمانکار دوم','COMPANY'),
        ])
        self.db.executemany('''INSERT INTO contracts
          (id,company_id,contract_no,title,employer_party_id,contractor_party_id,start_date,amount_rial)
          VALUES(?,?,?,?,?,?,?,?)''', [
            (1,1,'A1','نقشه برداری',1,2,'2026-10-01',50000000),
            (2,2,'B1','عمرانی',3,4,'2026-10-01',80000000),
        ])
        self.db.execute("INSERT INTO expenses(contract_id,expense_date,category,amount_rial) VALUES(1,'2026-10-03','تجهیزات',2000000)")
        self.db.execute("INSERT INTO expenses(contract_id,expense_date,category,amount_rial) VALUES(1,'2026-10-04','تجهیزات',1000000)")
        self.db.execute("INSERT INTO payments(contract_id,payment_date,amount_rial) VALUES(1,'2026-10-05',1000000)")
        self.db.execute("INSERT INTO receipts(contract_id,receipt_date,amount_rial) VALUES(1,'2026-10-06',1500000)")
        self.db.execute("INSERT INTO statements(contract_id,statement_no,statement_date,gross_rial,status) VALUES(1,'S1','2026-10-06',9000000,'APPROVED')")
        self.db.execute("INSERT INTO expenses(contract_id,expense_date,category,amount_rial) VALUES(2,'2026-10-03','مصالح',7000000)")
        self.db.commit()

    def tearDown(self):
        self.db.close()

    def test_independent_cost_paid_and_received(self):
        summary = self.db.execute('SELECT cost_rial,paid_rial,received_rial FROM v_contract_financial_summary WHERE contract_id=1').fetchone()
        self.assertEqual(summary, (3000000, 1000000, 1500000))

    def test_margin_is_approved_work_less_expense(self):
        summary = self.db.execute('SELECT approved_work_rial,provisional_margin_rial FROM v_contract_financial_summary WHERE contract_id=1').fetchone()
        self.assertEqual(summary, (9000000, 6000000))

    def test_cash_flow_is_not_profit(self):
        cash, provisional = self.db.execute('SELECT cash_flow_rial, provisional_margin_rial FROM v_contract_financial_summary WHERE contract_id=1').fetchone()
        self.assertEqual(cash, 500000)
        self.assertNotEqual(cash, provisional)

    def test_second_company_isolated(self):
        got = self.db.execute('''SELECT c.id,c.title FROM contracts c JOIN companies co ON co.id=c.company_id
          WHERE c.id=? AND c.company_id=?''', (2, 1)).fetchall()
        self.assertEqual(got, [])

    def test_report_rows_are_contract_scoped(self):
        first = self.db.execute('SELECT SUM(amount_rial) FROM expenses WHERE contract_id=?', (1,)).fetchone()[0]
        other = self.db.execute('SELECT SUM(amount_rial) FROM expenses WHERE contract_id=?', (2,)).fetchone()[0]
        self.assertEqual(first, 3000000)
        self.assertEqual(other, 7000000)

    def test_expenses_group_by_category(self):
        groups = self.db.execute('''SELECT category,SUM(amount_rial) FROM expenses WHERE contract_id=?
          GROUP BY category''', (1,)).fetchall()
        self.assertEqual(groups, [('تجهیزات', 3000000)])

    def test_monthly_receipts_and_payments_separate(self):
        received = self.db.execute("SELECT SUM(amount_rial) FROM receipts WHERE contract_id=1 AND receipt_date LIKE '2026-10-%'").fetchone()[0]
        paid = self.db.execute("SELECT SUM(amount_rial) FROM payments WHERE contract_id=1 AND payment_date LIKE '2026-10-%'").fetchone()[0]
        self.assertEqual((received, paid), (1500000, 1000000))

    def test_no_report_data_from_wrong_contract(self):
        query = '''SELECT c.*, e.full_name employer_name, k.full_name contractor_name,
          f.cost_rial, f.paid_rial, f.received_rial, f.approved_work_rial,
          f.approved_net_payable_rial, f.provisional_margin_rial, f.cash_flow_rial,
          co.name company_name
          FROM contracts c JOIN companies co ON co.id=c.company_id
          JOIN parties e ON e.id=c.employer_party_id
          JOIN parties k ON k.id=c.contractor_party_id
          JOIN v_contract_financial_summary f ON f.contract_id=c.id
          WHERE c.id=? AND c.company_id=? LIMIT 1'''
        self.assertEqual(self.db.execute(query, (1, 2)).fetchall(), [])
        self.assertEqual(len(self.db.execute(query, (1, 1)).fetchall()), 1)

    def test_invalid_cross_contract_allocation_is_rejected(self):
        other_payment = self.db.execute('''INSERT INTO payments(contract_id,payment_date,amount_rial)
          VALUES(2,'2026-10-07',1000000)''').lastrowid
        expense_id = self.db.execute('SELECT id FROM expenses WHERE contract_id=1 LIMIT 1').fetchone()[0]
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('''INSERT INTO expense_payment_allocations(expense_id,payment_id,amount_rial)
              VALUES(?,?,?)''', (expense_id, other_payment, 10000))

    def test_unapproved_statement_does_not_count_as_margin(self):
        self.db.execute("INSERT INTO statements(contract_id,statement_no,statement_date,gross_rial,status) VALUES(1,'S2','2026-10-08',20000000,'DRAFT')")
        self.assertEqual(self.db.execute('SELECT provisional_margin_rial FROM v_contract_financial_summary WHERE contract_id=1').fetchone()[0], 6000000)

    def test_zero_receipts_not_presented_as_zero_profit(self):
        self.db.execute('DELETE FROM receipts WHERE contract_id=1')
        row = self.db.execute('SELECT received_rial,provisional_margin_rial FROM v_contract_financial_summary WHERE contract_id=1').fetchone()
        self.assertEqual(row, (0, 6000000))


if __name__ == '__main__':
    unittest.main()
