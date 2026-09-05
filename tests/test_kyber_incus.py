"""Exercise the Kyber setup and firewall scripts without privileged operations."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INCUS = ROOT / "named-hosts/kyber/incus"
MOCK = r"""#!/usr/bin/env bash
set -eu
cmd="${0##*/}"
printf '%s %s\n' "$cmd" "$*" >> "$MOCK_LOG"
case "$cmd" in
  uname) echo "${MOCK_OS:-Linux}" ;;
  hostname) echo "${MOCK_HOST:-kyber}" ;;
  id)
    if [ "$1" = -un ]; then echo "${MOCK_USER:-ubuntu}"
    else echo "${MOCK_GROUPS:-ubuntu incus-admin}"; fi ;;
  sudo)
    [ "$1" != -n ] || shift
    [ "${MOCK_DENY_SUDO:-0}" = 0 ] || exit 1
    exec "$@" ;;
  incus)
    [ "$1 $2 $3" = '--force-local --project default' ] || exit 1
    shift 3
    [ "${MOCK_API_ERROR:-0}" = 0 ] || exit 1
    if [ "$1" = admin ]; then
      cat > "$MOCK_PRESEED"
    else
      case "${MOCK_INVENTORY:-empty}" in
        empty) echo '[]' ;;
        owned) echo '[{"name":"crabbox","config":{"user.dotfiles":"kyber-crabbox"}}]' ;;
        foreign) echo '[{"name":"crabbox","config":{}}]' ;;
        invalid) echo 'invalid' ;;
      esac
    fi ;;
  ip)
    [ "${MOCK_ROUTE_ERROR:-0}" = 0 ] || exit 1
    if [ "${4:-}" = default ]; then
      echo "${MOCK_DEFAULT_ROUTE-default via 192.0.2.1 dev eno1}"
    else echo "${MOCK_ROUTE:-}"; fi ;;
  iptables)
    [ "${MOCK_CHAIN_ERROR:-0}" = 0 ] || exit 1
    if [ "$2" = -C ]; then
      [ "${MOCK_RULES_EXIST:-0}" = 1 ] || exit 1
    fi ;;
esac
"""


class KyberIncusTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.log = self.directory / "calls.log"
        self.seed = self.directory / "preseed.yaml"
        for command in [
            "uname",
            "hostname",
            "id",
            "sudo",
            "incus",
            "ip",
            "iptables",
            "systemctl",
            "install",
            "usermod",
            "apt-get",
            "mkfs.btrfs",
        ]:
            path = self.directory / command
            path.write_text(MOCK)
            path.chmod(0o755)
        setup = (INCUS / "setup.sh").read_text()
        for placeholder, filename in [
            ("preseed", "preseed.yaml"),
            ("networkScript", "network.sh"),
            ("networkService", "kyber-incus-network.service"),
        ]:
            setup = setup.replace(f"@{placeholder}@", str(INCUS / filename))
        self.setup_script = self.directory / "setup.sh"
        self.setup_script.write_text(setup)
        self.env = {
            **os.environ,
            "PATH": f"{self.directory}:{os.environ['PATH']}",
            "MOCK_LOG": str(self.log),
            "MOCK_PRESEED": str(self.seed),
        }

    def run_script(self, script=None, **env):
        return subprocess.run(
            [shutil.which("bash"), str(script or self.setup_script)],
            env={**self.env, **env},
            capture_output=True,
            text=True,
            check=False,
        )

    def test_reapply_owned_setup_and_keep_default_profile(self):
        for _ in range(2):
            result = self.run_script(MOCK_INVENTORY="owned")
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.seed.read_text(), (INCUS / "preseed.yaml").read_text())
        calls = self.log.read_text()
        self.assertEqual(
            calls.splitlines().count(
                "incus --force-local --project default admin init --preseed"
            ),
            2,
        )
        self.assertNotIn("usermod ", calls)
        self.assertNotIn("delete", calls)
        self.assertNotIn("apt-get ", calls)
        self.assertIn("restart kyber-incus-network.service", calls)
        self.assertNotIn("name: default", self.seed.read_text())

    def test_fresh_setup_grants_only_operator_access(self):
        result = self.run_script(MOCK_GROUPS="ubuntu docker")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.log.read_text()
        self.assertIn("usermod -aG incus-admin ubuntu", calls)
        self.assertNotIn("restart incus.service", calls)

    def test_missing_packages_use_native_apt_before_configuration(self):
        (self.directory / "incus").unlink()
        (self.directory / "mkfs.btrfs").unlink()
        for command in ["bash", "env", "cat", "jq", "grep", "tr", "true"]:
            (self.directory / command).symlink_to(shutil.which(command))
        installer = self.directory / "apt-get"
        installer.write_text(
            MOCK
            + '\nif [ "$1" = install ]; then\n'
            + '  cp "$0" "${0%/*}/incus"\n'
            + '  cp "$0" "${0%/*}/mkfs.btrfs"\nfi\n'
        )
        (self.directory / "cp").symlink_to(shutil.which("cp"))
        result = self.run_script(PATH=str(self.directory))
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.log.read_text()
        self.assertIn("apt-get update", calls)
        self.assertIn("apt-get install -y incus incus-client btrfs-progs", calls)
        self.assertLess(calls.index("apt-get install"), calls.index("admin init"))

    def test_wrong_host_os_or_user_never_attempts_privileges(self):
        for env in [
            {"MOCK_HOST": "matic"},
            {"MOCK_HOST": "kamino"},
            {"MOCK_OS": "Darwin"},
            {"MOCK_USER": "root"},
        ]:
            with self.subTest(env=env):
                self.log.write_text("")
                result = self.run_script(**env)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Kyber only", result.stderr)
                self.assertNotIn("sudo ", self.log.read_text())

    def test_permission_inventory_and_route_errors_abort_before_preseed(self):
        for env in [
            {"MOCK_DENY_SUDO": "1"},
            {"MOCK_API_ERROR": "1"},
            {"MOCK_INVENTORY": "foreign"},
            {"MOCK_INVENTORY": "invalid"},
            {"MOCK_ROUTE_ERROR": "1"},
            {"MOCK_ROUTE": "10.203.0.0/24 dev another-bridge proto kernel"},
        ]:
            with self.subTest(env=env):
                result = self.run_script(**env)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.seed.exists())

    def test_own_bridge_route_is_safe_to_reapply(self):
        result = self.run_script(
            MOCK_ROUTE="10.203.0.0/24 dev incus-crabbox proto kernel"
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_network_rules_are_narrow_and_idempotent(self):
        result = self.run_script(INCUS / "network.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        inserts = [line for line in self.log.read_text().splitlines() if "-I " in line]
        self.assertEqual(len(inserts), 2)
        self.assertIn("-i incus-crabbox -o eno1 -j ACCEPT", inserts[0])
        self.assertIn("-i eno1 -o incus-crabbox", inserts[1])
        self.assertIn("--ctstate RELATED,ESTABLISHED", inserts[1])
        self.log.write_text("")
        result = self.run_script(INCUS / "network.sh", MOCK_RULES_EXIST="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("-I ", self.log.read_text())

    def test_no_firewall_mutation_without_route_or_docker_chain(self):
        for env in [
            {"MOCK_DEFAULT_ROUTE": ""},
            {"MOCK_ROUTE_ERROR": "1"},
            {"MOCK_CHAIN_ERROR": "1"},
        ]:
            with self.subTest(env=env):
                self.log.write_text("")
                result = self.run_script(INCUS / "network.sh", **env)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("-I ", self.log.read_text())


if __name__ == "__main__":
    unittest.main()
