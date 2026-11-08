import sqlite3, pathlib, unittest
SCHEMA = (pathlib.Path(__file__).resolve().parents[1] / 'assets' / 'db' / 'schema.sql').read_text(encoding='utf-8')

class TransferTest(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.execute('PRAGMA foreign_keys=ON')
        self.db.executescript(SCHEMA)
        self.db.execute("INSERT INTO companies(id,name) VALUES (1,'شرکت نمونه')")
        self.db.executemany("INSERT INTO parties(id,company_id,full_name,type) VALUES (?,?,?,?)",[(1,1,'کارفرما','COMPANY'),(2,1,'پیمانکار','COMPANY')])
        self.db.execute("INSERT INTO contracts(id,company_id,contract_no,title,employer_party_id,contractor_party_id,start_date,amount_rial) VALUES (1,1,'001','نقشه برداری',1,2,'2026-11-01',100000000)")
    def tearDown(self): self.db.close()
    def test_links_valid(self):
        with self.assertRaises(sqlite3.IntegrityError): self.db.execute("INSERT INTO expenses(contract_id,expense_date,category,amount_rial) VALUES (99,'2026-11-01','عملیات',10)")
    def test_prevent_negative_expense(self):
        with self.assertRaises(sqlite3.IntegrityError): self.db.execute("INSERT INTO expenses(contract_id,expense_date,category,amount_rial) VALUES (1,'2026-11-01','عملیات',-1)")
    def test_duplicated_contract_no(self):
        with self.assertRaises(sqlite3.IntegrityError): self.db.execute("INSERT INTO contracts(company_id,contract_no,title,employer_party_id,contractor_party_id,start_date,amount_rial) VALUES (1,'001','دیگر',1,2,'2026-11-01',1)")
    def test_profit_separate_from_cash(self):
        self.db.execute("INSERT INTO expenses(id,contract_id,expense_date,category,amount_rial) VALUES (1,1,'2026-11-02','دستمزد',20000000)")
        self.db.execute("INSERT INTO payments(id,contract_id,payment_date,amount_rial) VALUES (1,1,'2026-11-03',5000000)")
        self.db.execute("INSERT INTO receipts(id,contract_id,receipt_date,amount_rial) VALUES (1,1,'2026-11-03',10000000)")
        self.db.execute("INSERT INTO statements(id,contract_id,statement_no,statement_date,gross_rial,vat_rial,deductions_rial,status) VALUES (1,1,'SW-1','2026-11-03',40000000,4000000,2000000,'APPROVED')")
        result=self.db.execute('SELECT cost_rial,paid_rial,received_rial,approved_work_rial,approved_net_payable_rial,provisional_margin_rial,cash_flow_rial FROM v_contract_financial_summary WHERE contract_id=1').fetchone()
        self.assertEqual(result,(20000000,5000000,10000000,40000000,42000000,20000000,5000000))
    def test_unapproved_statement_not_profit(self):
        self.db.execute("INSERT INTO statements(contract_id,statement_no,statement_date,gross_rial,status) VALUES (1,'SW-1','2026-11-03',40000000,'SUBMITTED')")
        self.assertEqual(self.db.execute('SELECT approved_work_rial FROM v_contract_financial_summary').fetchone()[0],0)
    def test_invalid_progress(self):
        with self.assertRaises(sqlite3.IntegrityError): self.db.execute("INSERT INTO activities(contract_id,title,progress_percent) VALUES (1,'برداشت',101)")
    def test_invalid_deduction(self):
        with self.assertRaises(sqlite3.IntegrityError): self.db.execute("INSERT INTO statements(contract_id,statement_no,statement_date,gross_rial,deductions_rial) VALUES (1,'SW-1','2026-11-03',100,101)")
    def test_contract_dates(self):
        with self.assertRaises(sqlite3.IntegrityError): self.db.execute("INSERT INTO contracts(company_id,contract_no,title,employer_party_id,contractor_party_id,start_date,end_date,amount_rial) VALUES (1,'002','نادرست',1,2,'2026-11-10','2026-11-01',1)")
    def test_no_double_counting_cost_vs_payment(self):
        self.db.execute("INSERT INTO expenses(contract_id,expense_date,category,amount_rial) VALUES (1,'2026-11-02','اجاره',800)")
        self.db.execute("INSERT INTO payments(contract_id,payment_date,amount_rial) VALUES (1,'2026-11-03',800)")
        self.assertEqual(self.db.execute('SELECT cost_rial FROM v_contract_financial_summary').fetchone()[0],800)
    def test_empty_contract_zeroes(self):
        r=self.db.execute('SELECT cost_rial, paid_rial, received_rial, approved_work_rial, provisional_margin_rial FROM v_contract_financial_summary').fetchone()
        self.assertEqual(r,(0,0,0,0,0))
    def test_cross_contract_payment_rejected(self):
        self.db.execute("INSERT INTO contracts(id,company_id,contract_no,title,employer_party_id,contractor_party_id,start_date,amount_rial) VALUES (2,1,'002','پروژه دیگر',1,2,'2026-11-01',10000)")
        self.db.execute("INSERT INTO expenses(id,contract_id,expense_date,category,amount_rial) VALUES (1,1,'2026-11-02','ایاب',800)")
        self.db.execute("INSERT INTO payments(id,contract_id,payment_date,amount_rial) VALUES (1,2,'2026-11-03',800)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO expense_payment_allocations VALUES (1,1,100)")
    def test_overallocation_expense_rejected(self):
        self.db.execute("INSERT INTO expenses(id,contract_id,expense_date,category,amount_rial) VALUES (1,1,'2026-11-02','ایاب',800)")
        self.db.execute("INSERT INTO payments(id,contract_id,payment_date,amount_rial) VALUES (1,1,'2026-11-03',900)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO expense_payment_allocations VALUES (1,1,801)")
    def test_overallocation_statement_rejected(self):
        self.db.execute("INSERT INTO receipts(id,contract_id,receipt_date,amount_rial) VALUES (1,1,'2026-11-03',1000)")
        self.db.execute("INSERT INTO statements(id,contract_id,statement_no,statement_date,gross_rial,deductions_rial,status) VALUES (1,1,'SW-1','2026-11-03',1000,200,'APPROVED')")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO statement_receipt_allocations VALUES (1,1,900)")
    def test_pending_statement_cannot_allocate(self):
        self.db.execute("INSERT INTO receipts(id,contract_id,receipt_date,amount_rial) VALUES (1,1,'2026-11-03',1000)")
        self.db.execute("INSERT INTO statements(id,contract_id,statement_no,statement_date,gross_rial,status) VALUES (1,1,'SW-1','2026-11-03',1000,'SUBMITTED')")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO statement_receipt_allocations VALUES (1,1,900)")
    def test_allocated_statement_cannot_unapprove(self):
        self.db.execute("INSERT INTO receipts(id,contract_id,receipt_date,amount_rial) VALUES (1,1,'2026-11-03',1000)")
        self.db.execute("INSERT INTO statements(id,contract_id,statement_no,statement_date,gross_rial,status) VALUES (1,1,'SW-1','2026-11-03',1000,'APPROVED')")
        self.db.execute("INSERT INTO statement_receipt_allocations VALUES (1,1,900)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE statements SET status='DRAFT' WHERE id=1")
    def test_allocated_payment_cannot_shrink(self):
        self.db.execute("INSERT INTO expenses(id,contract_id,expense_date,category,amount_rial) VALUES (1,1,'2026-11-02','ایاب',1000)")
        self.db.execute("INSERT INTO payments(id,contract_id,payment_date,amount_rial) VALUES (1,1,'2026-11-03',1000)")
        self.db.execute("INSERT INTO expense_payment_allocations VALUES (1,1,900)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE payments SET amount_rial=800 WHERE id=1")
    def test_fk_on(self): self.assertEqual(self.db.execute('PRAGMA foreign_keys').fetchone()[0],1)
    def test_structure_integrity(self): self.assertEqual(self.db.execute('PRAGMA integrity_check').fetchone()[0],'ok')

if __name__ == '__main__': unittest.main(verbosity=2)
