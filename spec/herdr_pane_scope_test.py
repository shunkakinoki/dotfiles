import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "named-hosts/kyber/herdr-pane-scope.fish"


@unittest.skipUnless(
    sys.platform == "linux" and shutil.which("fish"), "Linux fish placement"
)
class HerdrPaneScopeTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.runner = self.directory / "systemd-run"
        self.runner.write_text('#!/bin/sh\nprintf "%s\\n" "$HERDR_PANE_SCOPED" "$@"\n')
        self.runner.chmod(0o755)
        cat = self.directory / "cat"
        cat.write_text('#!/bin/sh\nprintf "%s\\n" "$TEST_HERDR_CGROUP"\n')
        cat.chmod(0o755)
        self.environment = {
            "HOME": str(self.directory),
            "PATH": str(self.directory) + os.pathsep + os.environ["PATH"],
            "TERM": "dumb",
            "HERDR_ENV": "1",
            "TEST_HERDR_CGROUP": (
                "0::/user.slice/user@1000.service/herdr.slice/herdr-server.service"
            ),
        }

    def launch(self, interactive=True):
        command = [shutil.which("fish"), "--no-config"]
        if interactive:
            command.append("--interactive")
        command.extend(
            [
                "-c",
                'source "$argv[1]" "$argv[2]" /managed/fish "$argv[3]"; echo returned',
                "--",
                str(SCRIPT),
                str(self.runner),
                shutil.which("false"),
            ]
        )
        return subprocess.run(
            command, env=self.environment, capture_output=True, text=True, timeout=5
        )

    def test_ordinary_pane_enters_disposable_scope_before_agent_shell(self):
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.splitlines()[:6],
            [
                "1",
                "--user",
                "--quiet",
                "--scope",
                "--collect",
                "--slice=orchestration.slice",
            ],
        )
        self.assertRegex(result.stdout, r"--unit=herdr-pane-\d+\n/managed/fish\n$")
        self.assertNotIn("returned", result.stdout)

    def test_explicit_recovery_uses_separate_control_scope(self):
        self.environment["HERDR_PANE_ROLE"] = "recovery"
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--slice=herdr.slice\n", result.stdout)
        self.assertRegex(result.stdout, r"--unit=herdr-recovery-\d+\n/managed/fish\n$")
        self.assertNotIn("orchestration.slice", result.stdout)

    def test_unknown_role_refuses_launch(self):
        self.environment["HERDR_PANE_ROLE"] = "recovery-typo"
        for placement in (
            {},
            {
                "TEST_HERDR_CGROUP": (
                    "0::/user.slice/user@1000.service/herdr.slice/herdr-recovery-123.scope"
                )
            },
            {"HERDR_PANE_SCOPED": "1"},
        ):
            with self.subTest(placement=placement):
                self.environment.update(placement)
                result = self.launch()
                self.assertEqual(result.returncode, 1)
                self.assertIn("Unknown Herdr pane role", result.stderr)
                self.assertEqual(result.stdout, "")

    def test_scoped_shell_does_not_reenter_systemd(self):
        self.environment["HERDR_PANE_SCOPED"] = "1"
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "returned\n")

    def test_existing_recovery_scope_survives_shell_replacement(self):
        self.environment["HERDR_PANE_ROLE"] = "recovery"
        self.environment["TEST_HERDR_CGROUP"] = (
            "0::/user.slice/user@1000.service/herdr.slice/herdr-recovery-123.scope"
        )
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "returned\n")

    def test_noninteractive_and_nonherdr_shells_keep_their_owner(self):
        result = self.launch(interactive=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "returned\n")
        del self.environment["HERDR_ENV"]
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "returned\n")

    def test_operator_moved_recovery_scope_survives_without_role_environment(self):
        self.environment["TEST_HERDR_CGROUP"] = (
            "0::/user.slice/user@1000.service/herdr.slice/herdr-recovery-123.scope"
        )
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "returned\n")


if __name__ == "__main__":
    unittest.main()
