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
