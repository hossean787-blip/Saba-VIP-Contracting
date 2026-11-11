#!/usr/bin/env python3
"""Protect offline accounting data in the generated Android project.

Applied AFTER flutter create. Idempotent; never alters the package ID,
signature secrets, or existing data.
"""
import argparse
from pathlib import Path
import xml.etree.ElementTree as ET

ANDROID = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID)
A = lambda name: f"{{{ANDROID}}}{name}"

EXTRACTION = """<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
    <cloud-backup>
        <exclude domain="root" path="."/>
        <exclude domain="database" path="."/>
        <exclude domain="sharedpref" path="."/>
    </cloud-backup>
    <device-transfer>
        <exclude domain="root" path="."/>
        <exclude domain="database" path="."/>
        <exclude domain="sharedpref" path="."/>
    </device-transfer>
</data-extraction-rules>
"""
BACKUP_RULES = """<?xml version="1.0" encoding="utf-8"?>
<full-backup-content>
    <exclude domain="root" path="."/>
    <exclude domain="database" path="."/>
    <exclude domain="sharedpref" path="."/>
    <exclude domain="file" path="."/>
</full-backup-content>
"""


def patch_manifest(xml: str) -> str:
    root = ET.fromstring(xml)
    if root.tag != "manifest":
        raise ValueError("Expected Android manifest")
    app = root.find("application")
    if app is None:
        raise ValueError("Android application element not found")
    if root.find("application/activity") is None:
        raise ValueError("Android launcher activity not found")
    app.set(A("allowBackup"), "false")
    app.set(A("fullBackupContent"), "@xml/backup_rules")
    app.set(A("dataExtractionRules"), "@xml/data_extraction_rules")
    app.set(A("usesCleartextTraffic"), "false")
    app.set(A("label"), "پیمانکاری صبا VIP")
    if not any(tag.get(A("name")) == "android.permission.USE_BIOMETRIC"
               for tag in root.findall("uses-permission")):
        permission = ET.Element("uses-permission")
        permission.set(A("name"), "android.permission.USE_BIOMETRIC")
        root.insert(0, permission)
    return '<?xml version="1.0" encoding="utf-8"?>\n' + ET.tostring(
        root, encoding="unicode") + "\n"


def patch_activity(text: str) -> str:
    if "FlutterFragmentActivity" in text:
        return text
    if "import io.flutter.embedding.android.FlutterActivity" not in text:
        raise ValueError("Unexpected Flutter MainActivity")
    return text.replace(
        "import io.flutter.embedding.android.FlutterActivity",
        "import io.flutter.embedding.android.FlutterFragmentActivity"
    ).replace("FlutterActivity()", "FlutterFragmentActivity()")


def patch_style(text: str) -> str:
    if 'name="LaunchTheme"' not in text:
        raise ValueError("Missing Android LaunchTheme")
    import re
    changed = re.sub(
        r'(<style\s+name="LaunchTheme"\s+parent=")[^"]+(")',
        r'\1Theme.AppCompat.DayNight.NoActionBar\2', text)
    if changed == text and 'Theme.AppCompat.DayNight.NoActionBar' not in text:
        raise ValueError("Could not patch LaunchTheme")
    return changed


def harden(android: Path) -> None:
    app = android / "app/src/main"
    manifest = app / "AndroidManifest.xml"
    kotlin = list((app / "kotlin").rglob("MainActivity.kt"))
    if len(kotlin) != 1:
        raise ValueError("Expected exactly one Android MainActivity.kt")
    manifest_src = manifest.read_text(encoding="utf-8")
    activity_src = kotlin[0].read_text(encoding="utf-8")
    styles = [
        app / "res/values/styles.xml",
        app / "res/values-night/styles.xml",
    ]
    if not all(path.is_file() for path in styles):
        raise ValueError("Android styles are incomplete")
    patched = {
        manifest: patch_manifest(manifest_src),
        kotlin[0]: patch_activity(activity_src),
        **{path: patch_style(path.read_text(encoding="utf-8"))
           for path in styles},
    }
    for path, content in patched.items():
        path.write_text(content, encoding="utf-8")
    xml_dir = app / "res/xml"
    xml_dir.mkdir(parents=True, exist_ok=True)
    (xml_dir / "backup_rules.xml").write_text(
        BACKUP_RULES, encoding="utf-8")
    (xml_dir / "data_extraction_rules.xml").write_text(
        EXTRACTION, encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--android-dir", type=Path, default=Path("android"))
    args = parser.parse_args()
    harden(args.android_dir)
    print("Android offline-data backup rules and device-auth activity configured.")
