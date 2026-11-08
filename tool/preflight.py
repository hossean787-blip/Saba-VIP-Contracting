"""Offline source/package integrity preflight; not Dart/Android compilation."""
from pathlib import Path
import sqlite3
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SourcePreflight(unittest.TestCase):
    def test_relative_dart_imports_exist(self):
        for path in ROOT.joinpath('lib').rglob('*.dart'):
            for line in path.read_text(encoding='utf-8').splitlines():
                if line.strip().startswith("import '../") or line.strip().startswith("import './"):
                    rel = line.split("'", 2)[1]
                    self.assertTrue((path.parent / rel).resolve().is_file(), (path, rel))

    def test_font_download_script_present_and_not_bundled(self):
        self.assertTrue(ROOT.joinpath('tool/prepare_fonts.sh').is_file())
        self.assertFalse(ROOT.joinpath('assets/fonts/NotoNaskhArabic.ttf').exists())
        self.assertIn('assets/fonts/NotoNaskhArabic.ttf', ROOT.joinpath('pubspec.yaml').read_text())

    def test_seed_database_remains_empty_and_intact(self):
        c = sqlite3.connect(str(ROOT / 'assets/db/seed.sqlite'))
        try:
            self.assertEqual(c.execute('PRAGMA integrity_check').fetchone()[0], 'ok')
            self.assertEqual(c.execute('PRAGMA user_version').fetchone()[0], 1)
            for table in ['companies', 'parties', 'contracts', 'expenses', 'payments', 'receipts', 'statements']:
                self.assertEqual(c.execute(f'SELECT COUNT(*) FROM {table}').fetchone()[0], 0, table)
        finally:
            c.close()

    def test_reports_module_linked_to_both_navigation_paths(self):
        main = ROOT.joinpath('lib/main.dart').read_text()
        detail = ROOT.joinpath('lib/screens/contract_detail.dart').read_text()
        self.assertIn('ReportsScreen(', main)
        self.assertIn('ProjectReportScreen(', detail)

    def test_exports_are_typed_xlsx_and_pdf(self):
        text = ROOT.joinpath('lib/reports/report_exports.dart').read_text()
        self.assertIn('xl.IntCellValue', text)
        self.assertIn('pw.MultiPage(', text)
        self.assertIn('pw.TextDirection.rtl', text)


if __name__ == '__main__':
    unittest.main()
