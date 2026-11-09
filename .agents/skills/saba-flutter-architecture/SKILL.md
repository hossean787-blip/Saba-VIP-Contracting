---
name: saba-flutter-architecture
description: Build and refactor the offline Flutter/Dart finance, contract, SQLite, expense recognition and linked payment logic in Saba VIP Contracting, with data integrity and tests.
---

# Flutter architecture and finance — Saba VIP Contracting

Use this for contract features, expenses, payments, receipts, SQLite migrations, data errors, backups and performance-sensitive state changes.

Inspired by rcosteira79/android-skills (android-dev, android-data-layer, android-debugging, android-testing):
https://github.com/rcosteira79/android-skills
This is an original Flutter adaptation, NOT the upstream native Android/KMP skill copied verbatim or installed as a plugin.

## Do
1. First read AGENTS.md, pubspec.yaml, the relevant lib/data/, lib/finance/, lib/screens/ and tests. Respect existing APIs; never inject Kotlin, Compose, Room or new dependencies by default.
2. Put calculation and validation in lib/finance/, local SQLite and migrations in lib/data/, presentation in lib/screens/. Avoid raw SQL and money arithmetic in widgets. Handle asynchronous errors and double-submission.
3. Use integer rial end-to-end; UI may accept toman with explicit safe conversion. Validate overflow, zero, negative, grouping and malformed number inputs.
4. Ensure every expense, payment and receipt is linked to the correct contract. Use database transactions for multi-record changes. Rehearse migrations on existing data without destructive reset.
5. Payment rule: expense recognition always persists independently. Unpaid = 0 initial payment; full = recognized amount; partial = strictly positive and less than expense. Later payments reference the same expense and cannot cumulatively exceed its remaining amount.
6. Keep accrued/recognized amounts distinct from cash flow and certified statements. Maintain auditable history of each cash transaction; do not double-count.
7. Backups: encrypted exports and verified restore; never log secrets, personal details or financial payloads.

## Fast vertical-slice workflow
- Locate user action, model, validation, persistence query, reporting aggregate and related test.
- Write invariants and regression tests; make smallest cohesive change.
- Test unpaid, full, partial, additional settlement, zero/overpayment, repeated tap, contract mismatch and upgrade with existing data.
- Run flutter analyze and flutter test if SDK available; otherwise report those tests as blocked, not passed.
- Deliver changed file paths and commands/results, not promises.

## Reference test
For an expense of 1,000,000 rial: unpaid has paid=0, outstanding=1,000,000; full has paid=1,000,000, outstanding=0; partial 400,000 leaves 600,000. A follow-up payment of 600,000 is valid; 600,001 is rejected with no partial write.
