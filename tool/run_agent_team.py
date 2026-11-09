#!/usr/bin/env python3
"""Project-local specialist mission launcher. Planning costs nothing.
An AI session starts only with --execute and an authenticated Codex CLI.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MISSIONS = {
    'expense-settlement': {
        'title': 'Expense recognition and linked full/partial settlement',
        'discover': ['accounting_agent', 'database_agent', 'ui_designer'],
        'implement': ['app_developer'],
        'verify': ['testing_agent', 'security_agent', 'performance_agent'],
        'release': ['android_release'],
        'on_failure': ['debugger_agent'],
        'acceptance': [
            'Expense recognition succeeds with no payment tick and zero cash allocation.',
            'Full payment settles the exact expense, leaving zero balance.',
            'Partial amount is positive and smaller than the expense; balance is visible.',
            'Later linked payments never exceed the remaining expense amount.',
            'Contract isolation and nondestructive SQLite migrations remain correct.',
            'Recognized cost and actual cash are not double counted in reports.',
            'RTL, tests, release signature and device evidence are checked.'
        ]
    },
    'release-audit': {
        'title': 'Offline contracting Android release acceptance',
        'discover': ['testing_agent', 'security_agent', 'performance_agent'],
        'implement': [],
        'verify': ['accounting_agent', 'database_agent'],
        'release': ['android_release'],
        'on_failure': ['debugger_agent', 'app_developer'],
        'acceptance': [
            'Flutter analyze and tests pass for the exact source revision.',
            'SQLite integrity, migrations and finance reconciliation pass.',
            'Encrypted backup recovery and corruption cases are verified.',
            'APK certificate, package name, versionCode and SHA-256 are recorded.',
            'Phone install, offline use and PDF/XLSX rendering are device-tested or blocked.'
        ]
    },
    'ui-improvement': {
        'title': 'Persian RTL premium Flutter UI refinement',
        'discover': ['ui_designer', 'accounting_agent', 'performance_agent'],
        'implement': ['app_developer'],
        'verify': ['testing_agent', 'security_agent'],
        'release': ['android_release'],
        'on_failure': ['debugger_agent'],
        'acceptance': [
            'Keep current navy/champagne visual identity and real Flutter widgets.',
            'RTL, keyboard insets, text scaling and compact widths work correctly.',
            'Money amounts, payment status and Jalali dates remain accurate.',
            'Widget and financial regression tests pass.'
        ]
    }
}


def ensure_project(root):
    required = ['pubspec.yaml', 'AGENTS.md', '.codex/config.toml',
                '.codex/agents', '.agents/skills/saba-flutter-architecture/SKILL.md']
    missing = [p for p in required if not (root / p).exists()]
    if missing:
        raise ValueError('Missing project files: ' + ', '.join(missing))
    manifest = (root / 'pubspec.yaml').read_text(encoding='utf-8')
    if 'name: saba_vip_contracting' not in manifest:
        raise ValueError('Refusing to run outside Saba VIP Contracting')


def create_plan(root, mission):
    ensure_project(root)
    task = MISSIONS[mission]
    roles = list(dict.fromkeys(task['discover'] + task['implement'] +
                               task['verify'] + task['release'] + task['on_failure']))
    missing = [r for r in roles
               if not (root / '.codex/agents' / (r + '.toml')).is_file()]
    if missing:
        raise ValueError('Missing specialists: ' + ', '.join(missing))
    return {
        'mission': mission,
        'title': task['title'],
        'maximum_parallel_readers': 3,
        'stages': {
            'independent_read_only_review': task['discover'],
            'single_writer_implementation': task['implement'],
            'independent_qa': task['verify'],
            'release_verification': task['release'],
            'failure_triage_only': task['on_failure']
        },
        'acceptance': task['acceptance']
    }


def prompt(plan, read_only):
    mode = ('READ-ONLY AUDIT: do not edit source, data, secrets or CI.'
            if read_only else
            'IMPLEMENT the requested acceptance criteria, but do not push, merge, '
            'publish, rotate secrets, delete files or start paid workflows.')
    return '\n'.join([
        'Work exclusively in Saba-VIP-Contracting; never import other projects.',
        'Read AGENTS.md, docs/AGENT_TEAM_FA.md and applicable SKILL.md files.',
        'Use the native Codex subagent tools and exact configured specialist names.',
        'Do not claim subagents ran if orchestration tools are unavailable.',
        'Maximum three parallel independent reviewers, then synthesize findings.',
        'Mission: ' + plan['title'], mode,
        'Stages (invoke in order): ' + json.dumps(plan['stages'], ensure_ascii=False),
        'Shared finance/data files have ONE writer at a time.',
        'Debugger_agent runs only after an evidenced failing test or reproduced defect.',
        'Android release cannot claim APK or phone testing without real evidence.',
        'Acceptance:\n- ' + '\n- '.join(plan['acceptance']),
        'Return a Persian evidence report: edited files, exact commands, test counts, '
        'commit SHA, release identity and unresolved risks.'
    ])


def git_is_clean(root):
    try:
        status = subprocess.run(['git', 'status', '--porcelain'], cwd=str(root),
                                capture_output=True, text=True, check=False)
        return status.returncode == 0 and not status.stdout.strip()
    except OSError:
        return False


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['list', 'plan', 'run'])
    parser.add_argument('mission', nargs='?', choices=sorted(MISSIONS))
    parser.add_argument('--execute', action='store_true',
                        help='Start an actual Codex session; usage may be billable')
    parser.add_argument('--write', action='store_true',
                        help='Allow workspace edits, requires --execute and clean Git')
    args = parser.parse_args(argv)
    if args.command == 'list':
        for key, value in MISSIONS.items():
            print(key + ': ' + value['title'])
        return 0
    if not args.mission:
        parser.error('A mission is required')
    try:
        plan = create_plan(ROOT, args.mission)
    except (ValueError, OSError) as exc:
        print('PRECHECK FAILED: ' + str(exc), file=sys.stderr)
        return 2
    if args.command == 'plan':
        print(json.dumps(plan, ensure_ascii=False, indent=2))
        return 0
    if not args.execute:
        print('No AI session started. Specify --execute.', file=sys.stderr)
        return 2
    if args.write and not git_is_clean(ROOT):
        print('Write session blocked: Git worktree must be clean.', file=sys.stderr)
        return 2
    cli = shutil.which('codex')
    if not cli:
        print('BLOCKED: Codex CLI is not installed.', file=sys.stderr)
        return 3
    sandbox = 'workspace-write' if args.write else 'read-only'
    cmd = [cli, 'exec', '--cd', str(ROOT), '--sandbox', sandbox,
           '--ask-for-approval', 'never', '-']
    process = subprocess.run(cmd, input=prompt(plan, not args.write),
                             text=True, cwd=str(ROOT), check=False)
    return process.returncode


if __name__ == '__main__':
    sys.exit(main())
