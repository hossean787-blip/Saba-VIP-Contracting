"""Offline tests for specialized mission execution boundaries and QA gates."""
import contextlib
import io
import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tool'))
import run_agent_team as mission
import specialist_checks as gates


class MissionRunnerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.write('pubspec.yaml', 'name: saba_vip_contracting\n')
        self.write('AGENTS.md', '# Project\n')
        self.write('.codex/config.toml', '[agents]\nmax_concurrent_threads_per_session = 3\n')
        self.write('.agents/skills/saba-flutter-architecture/SKILL.md', '---\n')
        for name in {'app_developer', 'ui_designer', 'android_release',
                     'database_agent', 'accounting_agent', 'debugger_agent',
                     'testing_agent', 'security_agent', 'performance_agent'}:
            self.write('.codex/agents/' + name + '.toml', 'name = ' + name)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, name, value):
        p = self.root / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(value, encoding='utf-8')

    def test_all_missions_use_existing_roles_and_max_three_reviewers(self):
        for name in mission.MISSIONS:
            plan = mission.create_plan(self.root, name)
            self.assertLessEqual(len(plan['stages']['independent_read_only_review']), 3)
            self.assertEqual(plan['maximum_parallel_readers'], 3)
            self.assertTrue(plan['acceptance'])

    def test_wrong_project_rejected(self):
        self.write('pubspec.yaml', 'name: unrelated_app\n')
        with self.assertRaises(ValueError):
            mission.create_plan(self.root, 'expense-settlement')

    def test_missing_role_rejected(self):
        (self.root / '.codex/agents/accounting_agent.toml').unlink()
        with self.assertRaisesRegex(ValueError, 'accounting_agent'):
            mission.create_plan(self.root, 'expense-settlement')

    def test_expense_mission_has_one_writer_and_debugger_on_failure(self):
        p = mission.create_plan(self.root, 'expense-settlement')
        self.assertEqual(p['stages']['single_writer_implementation'], ['app_developer'])
        self.assertIn('database_agent', p['stages']['independent_read_only_review'])
        self.assertEqual(p['stages']['failure_triage_only'], ['debugger_agent'])
        self.assertIn('do not push, merge', mission.prompt(p, False))

    def test_cannot_launch_codex_without_explicit_execute(self):
        with patch.object(mission, 'ROOT', self.root), \
             patch.object(mission.subprocess, 'run') as run, \
             contextlib.redirect_stderr(io.StringIO()):
            code = mission.main(['run', 'expense-settlement'])
        self.assertEqual(code, 2)
        run.assert_not_called()

    def test_missing_codex_is_reported_not_faked(self):
        with patch.object(mission, 'ROOT', self.root), \
             patch.object(mission.shutil, 'which', return_value=None), \
             contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(mission.main(['run', 'expense-settlement', '--execute']), 3)

    def test_codex_commands_are_sandboxed_for_both_modes(self):
        for writable in (False, True):
            with self.subTest(writable=writable), \
                 patch.object(mission, 'ROOT', self.root), \
                 patch.object(mission.shutil, 'which', return_value='/usr/bin/codex'), \
                 patch.object(mission, 'git_is_clean', return_value=True), \
                 patch.object(mission.subprocess, 'run') as run:
                run.return_value.returncode = 0
                args = ['run', 'expense-settlement', '--execute']
                if writable:
                    args.append('--write')
                self.assertEqual(mission.main(args), 0)
                cmd = run.call_args.args[0]
                self.assertIn('workspace-write' if writable else 'read-only', cmd)
                self.assertIn('--sandbox', cmd)
                self.assertIn('never', cmd)
                self.assertEqual(cmd[1:4], ['--ask-for-approval', 'never', 'exec'])
                self.assertNotIn('--yolo', cmd)
                self.assertNotIn('danger-full-access', cmd)
                self.assertTrue(run.call_args.kwargs['input'])

    def test_write_mode_requires_clean_git(self):
        with patch.object(mission, 'ROOT', self.root), \
             patch.object(mission, 'git_is_clean', return_value=False), \
             patch.object(mission.subprocess, 'run') as run, \
             contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(mission.main(
                ['run', 'expense-settlement', '--execute', '--write']), 2)
        run.assert_not_called()


class SpecialistGateTests(unittest.TestCase):
    def test_exactly_nine_deterministic_role_gates(self):
        self.assertEqual(set(gates.GATES), {
            'app_developer', 'ui_designer', 'android_release',
            'database_agent', 'accounting_agent', 'debugger_agent',
            'testing_agent', 'security_agent', 'performance_agent'})

    def test_ui_checks_detect_missing_optional_payment_checkbox(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for path, txt in {
                'lib/core/theme.dart': '0xFF101A24 0xFFD5B77D',
                'lib/screens/entry_sheet.dart': 'if (partialExpensePayment) partialPaid',
                'lib/main.dart': "Locale('fa', 'IR')"
            }.items():
                f = root / path
                f.parent.mkdir(parents=True, exist_ok=True)
                f.write_text(txt, encoding='utf-8')
            with patch.object(gates, 'ROOT', root):
                valid, details = gates.validate_ui()
            self.assertFalse(valid)
            self.assertIn('payment optional', details)

    def test_database_smoke_is_read_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            dbpath = root / 'assets/db/seed.sqlite'
            dbpath.parent.mkdir(parents=True)
            db = sqlite3.connect(str(dbpath))
            db.execute('CREATE TABLE expenses(id INTEGER PRIMARY KEY, contract_id INTEGER)')
            db.commit()
            db.close()
            before = dbpath.read_bytes()
            with patch.object(gates, 'ROOT', root):
                valid, details = gates.validate_performance_baseline()
            self.assertTrue(valid, details)
            self.assertEqual(before, dbpath.read_bytes())

    def test_json_report_is_marked_non_ai_and_confined_to_repo(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            mock_result = {'role': 'ui_designer', 'status': 'passed',
                           'gate': 'test', 'detail': 'ok', 'elapsed_ms': 1}
            with patch.object(gates, 'ROOT', root), \
                 patch.object(gates, 'run_gate', return_value=mock_result), \
                 contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(gates.main([
                    '--role', 'ui_designer', '--output', 'dist/SPECIALIST_QA.json'
                ]), 0)
            result = json.loads((root / 'dist/SPECIALIST_QA.json').read_text())
            self.assertEqual(result['kind'], 'deterministic-specialist-qa-not-ai-agents')
            self.assertEqual(result['passed'], 1)


if __name__ == '__main__':
    unittest.main()
