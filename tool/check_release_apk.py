#!/usr/bin/env python3
"""Verify compiled Android privacy flags in a signed release APK."""
import os
from pathlib import Path
import re
import subprocess
import sys


def validate_manifest(text: str):
    required = {
        "automatic backup disabled":
            r"android:allowBackup[^\n]*(?:0x0\b|false)",
        "cleartext traffic disabled":
            r"android:usesCleartextTraffic[^\n]*(?:0x0\b|false)",
        "legacy backup exclusion":
            r"android:fullBackupContent",
        "Android 12 extraction rules":
            r"android:dataExtractionRules",
        "local device authentication":
            r"android.permission.USE_BIOMETRIC",
    }
    missing = [name for name, regex in required.items()
               if not re.search(regex, text)]
    if missing:
        raise ValueError("Missing release privacy flags: " + ", ".join(missing))


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: check_release_apk.py path/to/app.apk", file=sys.stderr)
        return 2
    apk = Path(sys.argv[1]).resolve()
    if not apk.is_file() or apk.stat().st_size < 10000:
        raise ValueError("APK does not exist or is empty")
    sdk = Path(os.environ["ANDROID_HOME"])
    candidates = sorted((sdk / "build-tools").glob("*/aapt"))
    if not candidates:
        raise ValueError("Android aapt was not found")
    output = subprocess.run(
        [str(candidates[-1]), "dump", "xmltree", str(apk),
         "AndroidManifest.xml"],
        check=True, capture_output=True, text=True)
    validate_manifest(output.stdout)
    print("PASS: Compiled APK privacy protections verified.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
