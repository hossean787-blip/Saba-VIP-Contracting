"""Regression checks: selected-project dashboard and ledgers never mix contracts."""
import sqlite3
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = (ROOT / "assets" / "db" / "schema.sql").read_text(encoding="utf-8")


class ActiveContractScopeTest(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.db.execute("PRAGMA foreign_keys=ON")
        self.db.executescript(SCHEMA)
        self.db.executemany("INSERT INTO companies(id,name) VALUES (?,?)",
                            [(1, "Main"), (2, "Other")])
        self.db.executemany(
            "INSERT INTO parties(id,company_id,full_name,type) VALUES (?,?,?,?)",
            [(1,1,"Employer","COMPANY"), (2,1,"Contractor","COMPANY"),
             (3,2,"Other Employer","COMPANY"), (4,2,"Other Contractor","COMPANY")],
        )
        self.db.executemany(
            """INSERT INTO contracts(id,company_id,contract_no,title,
                   employer_party_id,contractor_party_id,start_date,amount_rial)
               VALUES (?,?,?,?,?,?,?,?)""",
            [(10,1,"M","Municipality",1,2,"2026-01-01",1000000),
             (11,1,"I","Industrial",1,2,"2026-01-01",500000),
             (20,2,"O","Foreign",3,4,"2026-01-01",300000)],
        )
        for marker, contract_id in [(10,10), (11,11), (20,20)]:
            self.db.execute(
                "INSERT INTO expenses(contract_id,expense_date,category,amount_rial) "
                "VALUES (?,?,?,?)",
                (contract_id, "2026-11-08", "Transport", marker * 100),
            )
            self.db.execute(
                "INSERT INTO payments(contract_id,payment_date,amount_rial) VALUES (?,?,?)",
                (contract_id, "2026-11-08", marker * 90),
            )
            self.db.execute(
                "INSERT INTO receipts(contract_id,receipt_date,amount_rial) VALUES (?,?,?)",
                (contract_id, "2026-11-08", marker * 80),
            )
            self.db.execute(
                "INSERT INTO statements(contract_id,statement_no,statement_date,gross_rial) "
                "VALUES (?,?,?,?)",
                (contract_id, str(contract_id), "2026-11-08", marker * 70),
            )
            self.db.execute(
                "INSERT INTO activities(contract_id,title,progress_percent) VALUES (?,?,?)",
                (contract_id, "Work", 40),
            )

    def tearDown(self):
        self.db.close()

    def test_all_financial_lists_are_scoped(self):
        for table in ("expenses", "payments", "receipts", "statements"):
            for company, contract, expected in (
                (1,10,[10]), (1,11,[11]), (2,20,[20]), (1,20,[]), (2,10,[])
            ):
                sql = (f"SELECT t.contract_id FROM {table} t "
                       "JOIN contracts c ON c.id=t.contract_id "
                       "WHERE c.company_id=? AND t.contract_id=?")
                actual = self.db.execute(sql, (company, contract)).fetchall()
                self.assertEqual([row[0] for row in actual], expected)

    def test_activities_are_scoped(self):
        for company, contract, expected in ((1,10,1),(1,11,1),(1,20,0),(2,10,0)):
            sql = ("SELECT a.id FROM activities a JOIN contracts c ON c.id=a.contract_id "
                   "WHERE c.company_id=? AND a.contract_id=?")
            self.assertEqual(len(self.db.execute(sql, (company, contract)).fetchall()), expected)

    def test_dashboard_values_are_per_contract(self):
        sql = ("SELECT f.cost_rial FROM contracts c "
               "JOIN v_contract_financial_summary f ON f.contract_id=c.id "
               "WHERE c.company_id=? AND c.id=?")
        for company, contract, expected in ((1,10,1000),(1,11,1100),(2,20,2000)):
            self.assertEqual(self.db.execute(sql, (company, contract)).fetchone()[0], expected)
        self.assertIsNone(self.db.execute(sql, (1,20)).fetchone())


if __name__ == "__main__":
    unittest.main()
