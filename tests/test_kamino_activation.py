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
                arguments.extend(
                    [
                        "--hostname=kamino100",
                        "--accept-dns=false",
                        "--ssh=false",
                    ]
                )
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

    def test_tailscale_enrolls_and_sets_preferences_without_state_reset(self):
        result, log = self.run_phase("tailscale")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(
            log, ["tailscale up --hostname=kamino100 --accept-dns=false --ssh=false"]
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


class AuthorizedKeyTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.ssh_dir = self.root / "ssh"
        self.key = self.root / "client"
        subprocess.run(
            ["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(self.key)],
            check=True,
            capture_output=True,
        )
        self.public_key = Path(str(self.key) + ".pub")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        # Only ownership is mocked: tests run as an ordinary local user.
        chown = self.bin / "chown"
        chown.write_text('#!/bin/sh\nprintf "%s\\n" "$@" >"$OWNERSHIP_LOG"\n')
        chown.chmod(0o755)

    def authorize(self):
        return subprocess.run(
            [
                "/bin/bash",
                str(SCRIPT),
                "authorize-ssh",
                str(self.public_key),
                str(self.ssh_dir),
            ],
            env={
                **os.environ,
                "PATH": f"{self.bin}:{os.environ['PATH']}",
                "OWNERSHIP_LOG": str(self.root / "ownership"),
            },
            capture_output=True,
            text=True,
            timeout=10,
        )

    def test_fresh_install_authorizes_key_with_private_permissions(self):
        result = self.authorize()
        self.assertEqual(result.returncode, 0, result.stderr)
        authorized = self.ssh_dir / "authorized_keys"
        self.assertEqual(
            authorized.read_text().strip(), self.public_key.read_text().strip()
        )
        self.assertEqual(self.ssh_dir.stat().st_mode & 0o777, 0o700)
        self.assertEqual(authorized.stat().st_mode & 0o777, 0o600)
        self.assertEqual(
            (self.root / "ownership").read_text().splitlines(),
            ["root:root", str(self.ssh_dir), str(authorized)],
        )

    def test_reactivation_preserves_existing_entries_and_does_not_duplicate(self):
        self.ssh_dir.mkdir()
        authorized = self.ssh_dir / "authorized_keys"
        existing = "restrict ssh-ed25519 AAAAexisting provider-key"
        authorized.write_text(existing)  # Deliberately no trailing newline.
        for _ in range(2):
            result = self.authorize()
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            authorized.read_text().splitlines(),
            [existing, self.public_key.read_text().strip()],
        )

    def test_invalid_public_key_fails_before_creating_ssh_directory(self):
        self.public_key.write_text("not a public key\n")
        result = self.authorize()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.ssh_dir.exists())
