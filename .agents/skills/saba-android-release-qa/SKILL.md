---
name: saba-android-release-qa
description: Validate, build, sign and verify the Flutter-based Saba VIP Contracting APK with Android tools, offline-device checks, safe release practices and reproducible test evidence.
---

# Android release and quality — Saba VIP Contracting

Use this for build errors, Android SDK, APK packaging, signing, testing, performance, device compatibility and release decisions.

Inspired by the Google Android skills repository, especially android-cli, testing and security:
https://github.com/android/skills
https://github.com/android/skills/tree/main/devtools/android-cli
This is a Flutter adaptation, not a claim that Android CLI or Google skills have been installed system-wide.

## Detect tools first
Read AGENTS.md, pubspec.yaml, tool/ and .github/workflows/. Inspect tool availability using flutter --version, dart --version, adb version and optionally android --version. Do not run android skills add --all: that would install many unrelated native Android skills.

## Verification gates
1. Run flutter pub get, dart format --output=none --set-exit-if-changed lib test, flutter analyze and flutter test if installed. Existing Python SQLite tests are supplementary, never substitutes for Flutter tests.
2. Build with flutter build apk --release only when Flutter, Android SDK, JDK and required configuration exist. Diagnose errors before changing Gradle/AGP versions or adding dependencies.
3. Inspect version/package, requested permissions, certificate identity, APK SHA256 and APK signature with apksigner verify --verbose --print-certs and sha256sum (where present). Protect keystore secrets and keep signing identity stable for upgrades.
4. Test install, upgrade from previous released version, RTL layouts, Jalali dates, SQLite migrations, payment reconciliation, offline use, PDF/XLSX exports and encrypted backup/restore on a real Android device or emulator.
5. Review startup, low-memory screens, expensive SQLite queries, excessive rebuilds, logs containing financial data, backup encryption and file export permissions.
6. Report commit, tools, exact commands and exit codes, APK checksum, signing and device test outcome. If SDK or device is absent, mark the relevant gate BLOCKED; never invent success.

## Operational limits
Android CLI is OPTIONAL. Flutter and Android SDK are required for full APK creation. ADB or an emulator/device is required for direct install validation. GitHub Actions may cost quota; never trigger paid work or alter release workflows/secrets without consent.
