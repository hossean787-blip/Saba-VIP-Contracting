# Agent rules — Saba VIP Contracting

This repository is ONLY the independent Saba VIP Contracting app. Never import data, assets, code, decisions or secrets from any other project.

## Actual stack
- Flutter/Dart (pubspec.yaml), Android, Persian RTL and Jalali dates.
- Offline SQLite via sqflite; no mandatory backend, server or network account.
- PDF/XLSX reporting and encrypted local backups.
- Preserve existing navy/champagne visual theme in lib/core/theme.dart.
- Read lib/data/offline_store.dart, lib/finance/, lib/screens/, lib/reports/ and lib/security/ before changing related code.
- Monetary calculations use integer RIAL, with toman conversion ONLY at UI boundaries.

## Three skills to load
1. Architecture & finance: .agents/skills/saba-flutter-architecture/SKILL.md
2. Visual/RTL design: .agents/skills/saba-flutter-visual-design/SKILL.md
3. Android build & QA: .agents/skills/saba-android-release-qa/SKILL.md
Read docs/AGENT_SKILLS_FA.md for provenance and usage. The upstream native Android/Kotlin and web/CSS advice has been adapted to Flutter.

## Financial invariants
- Every recognized expense, income or payment must remain attached to its proper contract. Reject cross-contract links.
- Expense recognition is distinct from cash payment. No selected payment option means unpaid; full means the entire expense; partial requires 0 < amount < expense.
- Subsequent payments must link to the original expense. Total payments may not exceed its amount; track outstanding and historical payments.
- Do not confuse receipts with recognized revenue, or cash flow with profit. Keep reports and labels truthful.
- Use SQLite transactions for multi-table writes and preserve user data with nondestructive, tested migrations.

## Development loop
1. Inspect current source and tests; identify the smallest safe vertical slice.
2. Implement domain validation, persistence, screen and reporting consistently; add negative/boundary tests.
3. Where tools exist, run: flutter pub get; dart format --output=none --set-exit-if-changed lib test; flutter analyze; flutter test.
4. Build APK and test signing/install/upgrade ONLY when SDK and required permission exist. Do not claim tests passed unless run.
5. Report in Persian using exactly «تکمیل و آزموده‌شده», «در حال اجرا», or «متوقف به‌دلیل مانع» with evidence and next action.

Do not silently trigger paid CI, merge branches, publish releases, change secrets or signing keys, delete data, or alter unrelated repositories.


## Nine project-scoped subagents

This repository defines **nine actual subagent role configurations** for Codex in `.codex/agents/*.toml` and Claude Code in `.claude/agents/*.md`:
`app_developer`, `ui_designer`, `android_release`, `database_agent`, `accounting_agent`, `debugger_agent`, `testing_agent`, `security_agent`, `performance_agent`.

- Read `docs/AGENT_TEAM_FA.md` and `.codex/config.toml`. These are project-local and do not apply to other repositories.
- The parent/orchestrator must choose specialists relevant to a user task; **do not spawn all nine for every request**. Up to 3 may work concurrently, preferably on independent review tasks.
- Before editing shared finance/data files, appoint **one writer** and have accounting/database specialists review the plan. Never concurrently edit the same file.
- Prefer review/diagnosis by specialists, then a bounded implementation by app_developer/debugger_agent/database_agent, then independent testing and security review. android_release handles release QA only when needed and authorized.
- Review-only instructions do not create security isolation: all subagents inherit parent sandbox and approval controls.
- Merely committing these definitions does not launch autonomous agents or install the Codex/Claude CLI, Flutter SDK, or Android SDK. Do not claim runtime activation without an actual delegation test.


## Executable specialist missions and deterministic QA

The runnable, **opt-in** specialist coordinator is `tool/run_agent_team.py`. Read `docs/AGENT_EXECUTION_FA.md` before using it. Planning and role checks are offline: `python3 tool/run_agent_team.py plan expense-settlement`. A real Codex AI delegation requires an installed/authenticated CLI and explicit `run expense-settlement --execute`; code edits additionally require `--write` and a clean Git worktree. Do not claim the nine AI subagents have run until Codex reports their actual delegation.

The nine **deterministic** role-focused checks run using `python3 tool/specialist_checks.py --output dist/SPECIALIST_QA.json` in CI. They are ordinary Python/SQLite/static checks, **not AI agents**, and cannot substitute for Flutter tests, APK signature or on-device acceptance. The quality gates are intentionally read-only and never print credentials.
