#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo 'Flutter SDK not found. Install Flutter first.' >&2; exit 1; }
bash tool/prepare_fonts.sh
if [[ ! -d android ]]; then
  TEMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TEMP_DIR"' EXIT
  flutter create --platforms=android --org ir.saba.vip --project-name saba_vip_contracting "$TEMP_DIR/saba_vip_contracting"
  cp -a "$TEMP_DIR/saba_vip_contracting/android" .
fi
python3 tool/prepare_gradle_distribution.py
flutter pub get
printf 'Android scaffold ready. Run flutter analyze, flutter test, flutter build apk --release.\n'
