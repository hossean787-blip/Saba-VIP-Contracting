from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tool"))
from prepare_release_signing import patch_gradle, PACKAGE_ID

class SigningPatchTests(unittest.TestCase):
    EXAMPLE = '''plugins { id("com.android.application") }
android {
    namespace = "ir.saba.vip.saba_vip_contracting"
    defaultConfig { applicationId = "ir.saba.vip.saba_vip_contracting" }
    buildTypes { release { signingConfig = signingConfigs.getByName("debug") } }
}
'''

    def test_release_replaces_debug(self):
        out = patch_gradle(self.EXAMPLE)
        self.assertIn('signingConfigs.getByName("release")', out)
        self.assertNotIn('signingConfigs.getByName("debug")', out)
        self.assertIn('keyAlias = "saba_vip_release"', out)
        self.assertNotIn('storePassword = "', out)

    def test_preserves_package_id(self):
        self.assertIn(f'applicationId = "{PACKAGE_ID}"', patch_gradle(self.EXAMPLE))

    def test_rejects_other_app_id(self):
        with self.assertRaises(ValueError):
            patch_gradle(self.EXAMPLE.replace(PACKAGE_ID, "ir.example.other"))

    def test_rejects_changed_android_scaffold(self):
        with self.assertRaises(ValueError):
            patch_gradle(self.EXAMPLE.replace('getByName("debug")', 'getByName("release")'))

    def test_rejects_duplicate_debug_config(self):
        with self.assertRaises(ValueError):
            patch_gradle(self.EXAMPLE.replace('signingConfig =', 'signingConfig = signingConfigs.getByName("debug")\n        signingConfig =', 1))

if __name__ == "__main__":
    unittest.main()
