from pathlib import Path
from tempfile import TemporaryDirectory
import sys
import unittest
import xml.etree.ElementTree as ET

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tool"))
from harden_android import patch_manifest, patch_activity, patch_style, harden

MANIFEST = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
<application android:label="saba_vip_contracting" android:icon="@mipmap/ic_launcher">
<activity android:name=".MainActivity" android:exported="true"/>
</application></manifest>'''
ACTIVITY = '''package ir.saba.vip.saba_vip_contracting
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {}
'''
STYLE = '''<resources>
<style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
<item name="android:windowBackground">@drawable/launch_background</item>
</style></resources>'''

class AndroidReleasePrivacyTests(unittest.TestCase):
    def test_manifest_restricts_backups_and_plaintext(self):
        updated = patch_manifest(MANIFEST)
        app = ET.fromstring(updated).find("application")
        ns = "{http://schemas.android.com/apk/res/android}"
        self.assertEqual(app.get(ns + "allowBackup"), "false")
        self.assertEqual(app.get(ns + "usesCleartextTraffic"), "false")
        self.assertEqual(app.get(ns + "dataExtractionRules"),
                         "@xml/data_extraction_rules")
        self.assertEqual(app.get(ns + "fullBackupContent"), "@xml/backup_rules")
        self.assertEqual(updated.count("USE_BIOMETRIC"), 1)
        self.assertEqual(patch_manifest(updated).count("USE_BIOMETRIC"), 1)

    def test_activity_and_theme_idempotent(self):
        a = patch_activity(ACTIVITY)
        self.assertIn("FlutterFragmentActivity()", a)
        self.assertEqual(patch_activity(a), a)
        s = patch_style(STYLE)
        self.assertIn("Theme.AppCompat.DayNight.NoActionBar", s)
        self.assertEqual(patch_style(s), s)

    def test_hardener_builds_all_resources(self):
        with TemporaryDirectory() as directory:
            android = Path(directory) / "android"
            app = android / "app/src/main"
            kotlin = app / "kotlin/ir/saba/vip/saba_vip_contracting"
            kotlin.mkdir(parents=True)
            (kotlin / "MainActivity.kt").write_text(ACTIVITY)
            (app / "AndroidManifest.xml").write_text(MANIFEST)
            for name in ("values", "values-night"):
                folder = app / "res" / name
                folder.mkdir(parents=True)
                (folder / "styles.xml").write_text(STYLE)
            harden(android)
            harden(android)
            self.assertTrue((app / "res/xml/backup_rules.xml").is_file())
            self.assertTrue((app / "res/xml/data_extraction_rules.xml").is_file())
            self.assertIn('allowBackup="false"',
                          (app / "AndroidManifest.xml").read_text())
            self.assertIn("FlutterFragmentActivity",
                          (kotlin / "MainActivity.kt").read_text())

    def test_refuses_unknown_activity(self):
        with self.assertRaises(ValueError):
            patch_activity("class MainActivity {}")

if __name__ == "__main__":
    unittest.main()
