"""Run activation phases with inert OS commands, never touching host services."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "named-hosts/kamino/activate.sh"


class ActivationTests(unittest.TestCase):
    def run_phase(self, phase, *, saved="kamino100", uid="0", init="systemd", fail=""):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            identity = root / "identity"
            identity.write_text(saved)
            log = root / "log"
            commands = {
                "id": f"echo {uid}",
                "cat": 'if [ "$1" = /proc/1/comm ]; '
                f'then echo {init}; else /bin/cat "$@"; fi',
            }
            for name in ["hostnamectl", "loginctl", "systemctl", "mkdir", "tailscale"]:
                commands[name] = (
                    f'echo "{name} $*" >>"$COMMAND_LOG"\n'
                    f"exit {3 if name == fail else 0}"
                )
            for name, body in commands.items():
                command = root / name
                command.write_text("#!/bin/sh\n" + body + "\n")
                command.chmod(0o755)
            arguments = [phase, "kamino100"]
            if phase == "check":
                arguments.append(str(identity))
            if phase == "tailscale":
                arguments.append(str(root / "tailscale"))
            result = subprocess.run(
                ["/bin/bash", str(SCRIPT), *arguments],
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "PATH": f"{root}:/usr/bin:/bin",
                    "COMMAND_LOG": str(log),
                },
                timeout=10,
            )
            return result, log.read_text().splitlines() if log.exists() else []

    def test_identity_check_is_read_only_and_fails_closed(self):
        result, log = self.run_phase("check")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(log, [])
        for options in [dict(saved="kamino1"), dict(uid="1000"), dict(init="sh")]:
            result, log = self.run_phase("check", **options)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(log, [])

    def test_service_manager_order_and_failure(self):
        result, log = self.run_phase("user-manager")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(
            log,
            [
                "hostnamectl set-hostname kamino100",
                "loginctl enable-linger root",
                "systemctl start user@0.service",
            ],
        )
        result, log = self.run_phase("user-manager", fail="hostnamectl")
        self.assertEqual(result.returncode, 3)
        self.assertEqual(len(log), 1)

    def test_tailscale_sets_preferences_without_login_or_state_reset(self):
        result, log = self.run_phase("tailscale")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(
            log, ["tailscale set --hostname=kamino100 --accept-dns=false --ssh=false"]
        )
        result, _ = self.run_phase("tailscale", fail="tailscale")
        self.assertEqual(result.returncode, 3)
        self.assertNotIn("installed", result.stdout)

    def test_service_directory_and_unknown_phase(self):
        result, log = self.run_phase("prepare")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(log, ["mkdir -p /etc/sudoers.d"])
        result, log = self.run_phase("invalid")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(log, [])
