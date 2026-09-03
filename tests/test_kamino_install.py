"""Exercise the real piped installer using inert external commands."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "install.sh"


class InstallTests(unittest.TestCase):
    def run_installer(
        self,
        host,
        *,
        uid="0",
        system="Linux",
        init="systemd",
        saved=None,
        declared=True,
    ):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            binary = home / "bin"
            binary.mkdir()
            (home / "dotfiles").mkdir()
            if saved:
                identity = home / ".config/kamino/name"
                identity.parent.mkdir(parents=True)
                identity.write_text(saved + "\n")
            commands = {
                "uname": 'if [ "${1:-}" = -m ]; then echo x86_64; '
                f"else echo {system}; fi",
                "id": f'if [ "${{1:-}}" = -u ]; then echo {uid}; else echo root; fi',
                "cat": 'if [ "${1:-}" = /proc/1/comm ]; '
                f'then echo {init}; else /bin/cat "$@"; fi',
                "nix": "echo root" if declared else "exit 1",
                "git": "exit 0",
                "apt-get": "exit 0",
                "make": 'printf "INSTALL_HOST=%s INSTALL_USER=%s\\n" "$HOST" "$USER"',
                "curl": "exit 99",
            }
            for name, body in commands.items():
                command = binary / name
                command.write_text("#!/bin/sh\n" + body + "\n")
                command.chmod(0o755)
            return subprocess.run(
                ["/bin/sh"],
                input=SCRIPT.read_text(),
                text=True,
                capture_output=True,
                env={
                    **os.environ,
                    "PATH": f"{binary}:/usr/bin:/bin",
                    "HOME": str(home),
                    "HOST": host,
                    "USER": "stale-user",
                    "GITHUB_PR": "",
                },
                timeout=10,
            )

    def test_names_forwarded_as_root(self):
        for name in ["kamino", "kamino1", "KAMINO1", "kamino100"]:
            with self.subTest(name=name):
                result = self.run_installer(name)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(
                    f"INSTALL_HOST={name.lower()} INSTALL_USER=root", result.stdout
                )

    def test_repeat_install_keeps_identity(self):
        self.assertEqual(self.run_installer("KAMINO1", saved="kamino1").returncode, 0)

    def test_invalid_names_rejected_before_install(self):
        for name in ["kamino0", "kamino01", "kamino-1", "kamino*", "kamino1;id"]:
            result = self.run_installer(name)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("INSTALL_HOST=", result.stdout)

    def test_wrong_user_runtime_identity_or_undeclared_profile_rejected(self):
        for options in [
            dict(uid="1000"),
            dict(system="Darwin"),
            dict(init="sh"),
            dict(saved="kamino2"),
            dict(declared=False),
        ]:
            with self.subTest(options=options):
                result = self.run_installer("kamino1", **options)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("INSTALL_HOST=", result.stdout)
