"""Exercise the scan guard without traversing any real search root."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "named-hosts/kyber/find.sh"


class KyberFindTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name) / "home"
        self.home.mkdir()
        self.project = self.home / "project"
        self.project.mkdir()
        self.native = Path(self.temporary.name) / "native-find"
        self.native.write_text(
            f"#!{sys.executable}\nimport json, sys\nprint(json.dumps(sys.argv[1:]))\n"
        )
        self.native.chmod(0o755)

    def run_find(self, *arguments, cwd=None):
        return subprocess.run(
            ["bash", str(SCRIPT), str(self.native), *map(str, arguments)],
            cwd=cwd or self.project,
            env=os.environ | {"HOME": str(self.home)},
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )

    def assert_blocked(self, result):
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertIn("Kyber find:", result.stderr)

    def test_broad_roots_never_invoke_native_find(self):
        for root in (
            "/",
            "/home",
            "/root",
            self.home,
            self.home / ".herdr",
            self.home / ".herdr/worktrees",
            self.home / ".herdr/worktrees/repository",
        ):
            with self.subTest(root=root):
                self.assert_blocked(self.run_find(root, "-name", "state.json"))

    def test_default_root_and_relative_alias_are_checked(self):
        self.assert_blocked(self.run_find(cwd=self.home))
        self.assert_blocked(self.run_find("..", "-type", "f"))

    def test_symlink_to_home_is_checked(self):
        alias = self.project / "alias"
        alias.symlink_to(self.home)
        self.assert_blocked(self.run_find("-L", alias, "-type", "f"))

    def test_project_arguments_are_forwarded_exactly(self):
        args = [str(self.project), "-name", "file with spaces", "-print0"]
        result = self.run_find(*args)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), args)

    def test_one_worktree_is_allowed(self):
        root = self.home / ".herdr/worktrees/repository/worker"
        result = self.run_find(root, "-type", "f")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_shallow_inventory_is_allowed(self):
        for depth in (0, 1, 2):
            result = self.run_find("-H", self.home, "-maxdepth", depth, "-type", "d")
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_large_or_repeated_depth_does_not_authorize_scan(self):
        self.assert_blocked(self.run_find("/", "-maxdepth", 3))
        self.assert_blocked(self.run_find("/", "-maxdepth", 2, "-maxdepth", 99))

    def test_depth_inside_exec_does_not_authorize_scan(self):
        self.assert_blocked(self.run_find("/", "-exec", "echo", "-maxdepth", 2, ";"))

    def test_one_broad_root_rejects_entire_invocation(self):
        self.assert_blocked(self.run_find(self.project, self.home, "-print"))

    def test_indirect_roots_are_rejected(self):
        self.assert_blocked(self.run_find("-files0-from", "roots.txt", "-maxdepth", 1))

    def test_help_and_version_are_allowed_from_home(self):
        for flag in ("--help", "--version"):
            self.assertEqual(self.run_find(flag, cwd=self.home).returncode, 0)


if __name__ == "__main__":
    unittest.main()
