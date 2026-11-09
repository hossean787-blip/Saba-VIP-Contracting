import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tool"))
from prepare_gradle_distribution import change_wrapper

class GradleMirrorTests(unittest.TestCase):
    def test_generated_gradle_wrapper_uses_direct_binary(self):
        original = ("distributionBase=GRADLE_USER_HOME\n"
                    "distributionUrl=https\\://services.gradle.org/distributions/gradle-9.3.1-all.zip\n"
                    "zipStoreBase=GRADLE_USER_HOME\n")
        changed = change_wrapper(original)
        self.assertIn(
            "distributionUrl=https\\://downloads.gradle.org/distributions/gradle-9.3.1-bin.zip",
            changed)
        self.assertIn("distributionBase=GRADLE_USER_HOME", changed)
        self.assertIn("zipStoreBase=GRADLE_USER_HOME", changed)
        self.assertEqual(change_wrapper(changed), changed)

    def test_unknown_wrapper_is_rejected(self):
        with self.assertRaises(ValueError):
            change_wrapper("distributionUrl=https\\://unknown.example/file.zip")
        with self.assertRaises(ValueError):
            change_wrapper("empty=true")

if __name__ == "__main__":
    unittest.main()
