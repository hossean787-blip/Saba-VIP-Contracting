#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets/fonts
FONT="assets/fonts/NotoNaskhArabic.ttf"
if [[ -s "$FONT" ]]; then exit 0; fi
# Google Fonts Noto Naskh Arabic; copyright Google, SIL Open Font License 1.1.
# The font is downloaded at build time and not redistributed with the source archive.
URL='https://raw.githubusercontent.com/google/fonts/main/ofl/notonaskharabic/NotoNaskhArabic%5Bwght%5D.ttf'
command -v curl >/dev/null || { echo 'curl is required to prepare the licensed PDF font' >&2; exit 1; }
curl -fLSs --retry 3 --connect-timeout 15 "$URL" -o "$FONT.tmp"
python3 - "$FONT.tmp" <<'PY'
import sys
from pathlib import Path
p = Path(sys.argv[1]); raw = p.read_bytes()
if len(raw) < 40000 or raw[:4] not in (b'\x00\x01\x00\x00', b'OTTO', b'true'):
    raise SystemExit('Downloaded font is not a plausible OpenType/TrueType font')
PY
mv "$FONT.tmp" "$FONT"
echo 'Verified Noto Naskh Arabic font prepared for offline PDF exports.'
