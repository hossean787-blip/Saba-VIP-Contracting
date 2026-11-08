import sqlite3
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEED = ROOT / 'assets/db/seed.sqlite'
OPERATIONS_SQL = '''
SELECT a.*, c.title AS contract_title, c.contract_no
FROM activities a JOIN contracts c ON a.contract_id=c.id
WHERE c.company_id=?
ORDER BY CASE a.status WHEN 'IN_PROGRESS' THEN 0 WHEN 'PLANNED' THEN 1 ELSE 2 END,
 a.planned_date DESC, a.id DESC
'''


class OperationsIsolationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.db_path = Path(self.tmp.name) / 'test.db'
        self.db_path.write_bytes(SEED.read_bytes())
        self.db = sqlite3.connect(self.db_path)
        self.db.execute('PRAGMA foreign_keys=ON')
        for cid, company in [(1, 'Company A'), (2, 'Company B')]:
            self.db.execute('INSERT INTO companies(id,name) VALUES(?,?)', (cid, company))
            for party_id in [cid * 10, cid * 10+1]:
                self.db.execute('INSERT INTO parties(id,company_id,full_name,type) VALUES(?,?,?,?)',
                                (party_id, cid, f'Party{party_id}', 'COMPANY'))
            self.db.execute('''INSERT INTO contracts(id,company_id,contract_no,title,employer_party_id,contractor_party_id,start_date,amount_rial)
                 VALUES (?,?,?,?,?,?,?,?)''', (cid, cid, str(cid), company+' Project', cid*10, cid*10+1, '2026-11-09', 10000))
            self.db.execute('INSERT INTO activities(id,contract_id,title,progress_percent,status,planned_date) VALUES(?,?,?,?,?,?)',
                            (cid, cid, company+' Operation', 0, 'PLANNED', '2026-11-20'))
        self.db.commit()

    def tearDown(self):
        self.db.close()
        self.tmp.cleanup()

    def test_only_own_company_activities(self):
        self.assertEqual([r[0] for r in self.db.execute(OPERATIONS_SQL, (1,)).fetchall()], [1])
        self.assertEqual([r[0] for r in self.db.execute(OPERATIONS_SQL, (2,)).fetchall()], [2])

    def test_update_scoped_to_contract(self):
        cur = self.db.execute("UPDATE activities SET progress_percent=?,status='IN_PROGRESS' WHERE id=? AND contract_id=?",(55,1,1))
        self.assertEqual(cur.rowcount, 1)
        self.assertEqual(self.db.execute('SELECT progress_percent FROM activities WHERE id=1').fetchone()[0],55)
        cur = self.db.execute("UPDATE activities SET progress_percent=100 WHERE id=? AND contract_id=?",(1,2))
        self.assertEqual(cur.rowcount, 0)
        self.assertEqual(self.db.execute('SELECT progress_percent FROM activities WHERE id=2').fetchone()[0],0)

    def test_invalid_percent_blocked_by_database(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('UPDATE activities SET progress_percent=101 WHERE id=1')

    def test_database_snapshot_openable_and_integrity_check(self):
        self.db.close()
        b = self.db_path.read_bytes()
        copied = Path(self.tmp.name) / 'copied.db'
        copied.write_bytes(b)
        c = sqlite3.connect(f'file:{copied}?mode=ro', uri=True)
        self.assertEqual(c.execute('PRAGMA user_version').fetchone()[0],1)
        self.assertEqual(c.execute('PRAGMA quick_check').fetchone()[0],'ok')
        self.assertEqual(c.execute('PRAGMA foreign_key_check').fetchall(),[])
        self.assertEqual(c.execute('SELECT COUNT(*) FROM activities').fetchone()[0],2)
        c.close()
        self.db = sqlite3.connect(self.db_path)

    def test_corrupt_database_rejected(self):
        bad = Path(self.tmp.name) / 'bad.db'
        bad.write_bytes(b'not an sqlite database')
        with self.assertRaises(sqlite3.DatabaseError):
            c = sqlite3.connect(f'file:{bad}?mode=ro', uri=True)
            try:
                c.execute('PRAGMA quick_check').fetchone()
            finally:
                c.close()


if __name__ == '__main__':
    unittest.main()
