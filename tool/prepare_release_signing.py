#!/usr/bin/env python3
"""Configure generated Flutter Android scaffold with private permanent signing."""
import base64
import binascii
import os
from pathlib import Path
import subprocess
import sys

ALIAS = "saba_vip_release"
PACKAGE_ID = "ir.saba.vip.saba_vip_contracting"
DEBUG_SIGNING = 'signingConfig = signingConfigs.getByName("debug")'
RELEASE_SIGNING = 'signingConfig = signingConfigs.getByName("release")'

SIGNING_CONFIG = '''
    signingConfigs {
        create("release") {
            storeFile = file("saba_vip_release.p12")
            storePassword = System.getenv("SABA_RELEASE_STORE_PASSWORD")
            keyAlias = "saba_vip_release"
            keyPassword = System.getenv("SABA_RELEASE_STORE_PASSWORD")
        }
    }
'''

def patch_gradle(src: str) -> str:
    if f'applicationId = "{PACKAGE_ID}"' not in src:
        raise ValueError("Expected Android applicationId missing; refusing package rename")
    if src.count("android {") != 1:
        raise ValueError("Unexpected Android Gradle Kotlin structure")
    if src.count(DEBUG_SIGNING) != 1:
        raise ValueError("Expected temporary debug signing entry missing")
    return (src.replace("android {", "android {" + SIGNING_CONFIG, 1)
               .replace(DEBUG_SIGNING, RELEASE_SIGNING, 1))

def main() -> int:
    encoded = os.environ.get("SABA_RELEASE_KEYSTORE_B64", "").strip()
    password = os.environ.get("SABA_RELEASE_STORE_PASSWORD", "")
    if not encoded or not password:
        print("ERROR: Configure SABA_RELEASE_KEYSTORE_B64 and SABA_RELEASE_STORE_PASSWORD in GitHub Actions repository Secrets.", file=sys.stderr)
        return 2
    try:
        raw = base64.b64decode("".join(encoded.split()), validate=True)
    except binascii.Error:
        print("ERROR: Keystore secret is not valid base64.", file=sys.stderr)
        return 2
    if len(raw) < 1000:
        print("ERROR: Keystore secret is too small to be PKCS12.", file=sys.stderr)
        return 2
    gradle_file = Path("android/app/build.gradle.kts")
    if not gradle_file.is_file():
        print("ERROR: Flutter Android scaffold is missing.", file=sys.stderr)
        return 2
    patched = patch_gradle(gradle_file.read_text(encoding="utf-8"))
    key_file = gradle_file.parent / "saba_vip_release.p12"
    key_file.write_bytes(raw)
    key_file.chmod(0o600)
    try:
        subprocess.run(
            ["keytool", "-list", "-keystore", str(key_file), "-storetype", "PKCS12",
             "-alias", ALIAS, "-storepass:env", "SABA_RELEASE_STORE_PASSWORD"],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except (OSError, subprocess.CalledProcessError):
        key_file.unlink(missing_ok=True)
        print("ERROR: Invalid keystore, password or alias.", file=sys.stderr)
        return 2
    gradle_file.write_text(patched, encoding="utf-8")
    print("OK: Permanent release signing installed; no credentials printed.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
