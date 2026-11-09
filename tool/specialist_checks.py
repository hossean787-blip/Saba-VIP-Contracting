#!/usr/bin/env python3
"""Nine deterministic, offline specialist QA gates, NOT AI subagent sessions.
They complement (never replace) Flutter analyze/test, APK and device testing.
"""
import argparse
import json
import sqlite3
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
GATES = {
    'app_developer': ('Dart delimiter preflight',
                      [sys.executable, 'tool/check_dart_delimiters.py']),
    'ui_designer': ('Persian RTL form and established theme assertions', None),
    'android_release': ('Release-signing configuration regression',
                        [sys.executable, '-m', 'unittest', 'discover',
                         '-s', 'tests_python', '-p', 'test_release_signing_config.py']),
    'database_agent': ('SQLite expense contract isolation',
                       [sys.executable, '-m', 'unittest', 'discover',
                        '-s', 'tests_python', '-p', 'test_expense_payment_flow.py']),
    'accounting_agent': ('Recognized expense and cash report reconciliation',
                         [sys.executable, '-m', 'unittest', 'discover',
                          '-s', 'tests_python', '-p', 'test_report_projection.py']),
    'debugger_agent': ('Historic contract and activity regressions',
                       [sys.executable, '-m', 'unittest', 'discover',
                        '-s', 'tests_python', '-p', 'test_v03_operations.py']),
    'testing_agent': ('Full Python/SQLite regression suite',
                      [sys.executable, '-m', 'unittest', 'discover',
                       '-s', 'tests_python', '-p', 'test_*.py']),
    'security_agent': ('Offline Android safety regressions',
                       [sys.executable, '-m', 'unittest', 'discover',
                        '-s', 'tests_python', '-p', 'test_android_foundation.py']),
    'performance_agent': ('Read-only SQLite integrity and query-plan smoke', None)
}


def validate_ui():
    theme = (ROOT / 'lib/core/theme.dart').read_text(encoding='utf-8')
    entry = (ROOT / 'lib/screens/entry_sheet.dart').read_text(encoding='utf-8')
    main = (ROOT / 'lib/main.dart').read_text(encoding='utf-8')
    requirements = {
        'navy theme': '0xFF101A24' in theme,
        'champagne theme': '0xFFD5B77D' in theme,
        'persian locale': "Locale('fa', 'IR')" in main,
        'payment optional': 'registerExpensePayment' in entry,
        'partial conditional field': 'if (partialExpensePayment)' in entry,
        'partial amount controller': 'partialPaid' in entry,
    }
    missing = [name for name, ok in requirements.items() if not ok]
    return not missing, 'Missing UI markers: ' + ', '.join(missing) if missing else 'All static UI markers present'


def validate_performance_baseline():
    path = ROOT / 'assets/db/seed.sqlite'
    db = sqlite3.connect('file:' + str(path) + '?mode=ro', uri=True)
    try:
        integrity = db.execute('PRAGMA integrity_check').fetchone()[0]
        fks = db.execute('PRAGMA foreign_key_check').fetchall()
        plan = db.execute(
            'EXPLAIN QUERY PLAN SELECT id FROM expenses WHERE contract_id=?',
            (1,)).fetchall()
        ok = integrity == 'ok' and not fks and bool(plan)
        return ok, 'integrity=' + str(integrity) + '; FK violations=' + str(len(fks)) + '; query plan=' + str(bool(plan))
    finally:
        db.close()


def run_gate(role):
    title, cmd = GATES[role]
    begin = time.monotonic()
    try:
        if role == 'ui_designer':
            ok, detail = validate_ui()
        elif role == 'performance_agent':
            ok, detail = validate_performance_baseline()
        else:
            process = subprocess.run(cmd, cwd=str(ROOT), text=True,
                                     capture_output=True, timeout=120, check=False)
            ok = process.returncode == 0
            detail = 'exit=' + str(process.returncode) + '; ' + (
                process.stdout + '\n' + process.stderr).strip()[-1200:]
    except (OSError, sqlite3.Error, subprocess.TimeoutExpired) as exc:
        ok, detail = False, type(exc).__name__ + ': ' + str(exc)
    return {'role': role, 'gate': title, 'status': 'passed' if ok else 'failed',
            'detail': detail, 'elapsed_ms': round((time.monotonic() - begin) * 1000)}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--role', choices=sorted(GATES))
    parser.add_argument('--output', help='Write a JSON report within this repository')
    args = parser.parse_args(argv)
    roles = [args.role] if args.role else list(GATES)
    report = {'kind': 'deterministic-specialist-qa-not-ai-agents',
              'roles': [run_gate(role) for role in roles]}
    report['passed'] = sum(r['status'] == 'passed' for r in report['roles'])
    report['failed'] = len(roles) - report['passed']
    for result in report['roles']:
        print(('[PASS] ' if result['status'] == 'passed' else '[FAIL] ') +
              result['role'] + ': ' + result['gate'])
        if result['status'] != 'passed':
            print(result['detail'], file=sys.stderr)
    if args.output:
        output = (ROOT / args.output).resolve()
        if ROOT not in output.parents:
            parser.error('output path must stay within the project')
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
        print('Report: ' + str(output.relative_to(ROOT)))
    print('Passed %d/%d offline specialist QA gates' % (report['passed'], len(roles)))
    return 1 if report['failed'] else 0


if __name__ == '__main__':
    sys.exit(main())
