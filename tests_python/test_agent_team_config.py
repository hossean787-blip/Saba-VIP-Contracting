"""Contracting app local agent definitions — offline structural regression tests."""
import pathlib
import re
import unittest

try:
    import tomllib
except ImportError:
    tomllib = None

ROOT = pathlib.Path(__file__).resolve().parents[1]
ROLES = {
    "app_developer",
    "ui_designer",
    "android_release",
    "database_agent",
    "accounting_agent",
    "debugger_agent",
    "testing_agent",
    "security_agent",
    "performance_agent",
}


class ContractingAgentTeamTests(unittest.TestCase):
    def test_exact_nine_codex_roles(self):
        paths = {p.stem for p in (ROOT / ".codex" / "agents").glob("*.toml")}
        self.assertEqual(paths, ROLES)

    def test_exact_nine_claude_roles(self):
        paths = {p.stem for p in (ROOT / ".claude" / "agents").glob("*.md")}
        self.assertEqual(paths, ROLES)

    @unittest.skipIf(tomllib is None, "requires Python 3.11+ tomllib")
    def test_codex_roles_parse_with_required_fields(self):
        for role in sorted(ROLES):
            with self.subTest(role=role):
                path = ROOT / ".codex" / "agents" / (role + ".toml")
                data = tomllib.loads(path.read_text(encoding="utf-8"))
                self.assertEqual(data["name"], role)
                self.assertTrue(data["description"].strip())
                self.assertIn("Saba-VIP-Contracting", data["developer_instructions"])
                self.assertIn(".agents/skills/", data["developer_instructions"])
                self.assertIn("approval", data["developer_instructions"])
                self.assertFalse("sandbox_mode" in data)
                self.assertFalse("approval_policy" in data)

    @unittest.skipIf(tomllib is None, "requires Python 3.11+ tomllib")
    def test_project_config_limits_concurrency(self):
        data = tomllib.loads(
            (ROOT / ".codex" / "config.toml").read_text(encoding="utf-8")
        )
        self.assertTrue(data["features"]["multi_agent"])
        self.assertTrue(data["agents"]["enabled"])
        self.assertEqual(data["agents"]["max_concurrent_threads_per_session"], 3)

    def test_claude_yaml_frontmatter(self):
        for role in sorted(ROLES):
            with self.subTest(role=role):
                text = (ROOT / ".claude" / "agents" /
                        (role + ".md")).read_text(encoding="utf-8")
                self.assertTrue(text.startswith("---\n"))
                match = re.match(r"\A---\n(?P<meta>.*?)\n---\n", text, re.S)
                self.assertIsNotNone(match)
                meta = match.group("meta")
                self.assertIn("name: " + role + "\n", meta + "\n")
                self.assertRegex(meta, r"(?m)^description: \S+")
                self.assertIn("Saba-VIP-Contracting", text)

    def test_referenced_skills_exist(self):
        for role in ROLES:
            text = (ROOT / ".codex" / "agents" /
                    (role + ".toml")).read_text(encoding="utf-8")
            refs = re.findall(
                r"\.agents/skills/[a-z0-9-]+/SKILL\.md", text
            )
            self.assertGreaterEqual(len(refs), 1, role)
            for ref in refs:
                self.assertTrue((ROOT / ref).is_file(), ref)

    def test_application_entrypoints_still_exist(self):
        self.assertTrue((ROOT / "pubspec.yaml").is_file())
        self.assertTrue((ROOT / "lib" / "data" / "offline_store.dart").is_file())
        self.assertTrue((ROOT / "lib" / "finance" / "expense_payment.dart").is_file())


if __name__ == "__main__":
    unittest.main()
