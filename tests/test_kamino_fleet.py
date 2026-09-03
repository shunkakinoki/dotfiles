"""Read-only fleet verification fails closed; no live tailnet needed."""

import contextlib
import importlib.util
import io
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "kamino_fleet", ROOT / "named-hosts/kamino/fleet.py"
)
fleet = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(fleet)


class FleetTests(unittest.TestCase):
    def setUp(self):
        self.machine = {
            "name": "kamino1",
            "hostname": "kamino1.example.ts.net",
            "user": "root",
        }
        self.node = {
            "ID": "node-1",
            "DNSName": "kamino1.example.ts.net.",
            "Online": True,
            "TailscaleIPs": ["100.64.0.1"],
        }
        self.probe = "root\nkamino1\nherdr 1\ntmux 3\nzellij 1\nactive\n"

    def test_patterns_and_no_empty_success(self):
        inventory = {"machines": [self.machine]}
        for pattern in ["kamino*", "kamino1", "kamino?"]:
            self.assertEqual(fleet.select_machines(inventory, pattern), [self.machine])
        with self.assertRaises(ValueError):
            fleet.select_machines(inventory, "kamino2")

    def test_strict_ssh_bound_to_observed_node_and_tools(self):
        with patch.object(fleet, "run", return_value=self.probe) as run:
            result = fleet.verify_machines([self.machine], [self.node])[0]
        self.assertEqual(result["status"], "pass")
        self.assertEqual(result["node_id"], "node-1")
        command = run.call_args.args[0]
        for option in [
            "StrictHostKeyChecking=yes",
            "BatchMode=yes",
            "ControlPath=none",
            "HostName=100.64.0.1",
            "HostKeyAlias=kamino1.example.ts.net",
        ]:
            self.assertIn(option, command)
        for probe in [
            "herdr --version",
            "tmux -V",
            "zellij --version",
            "herdr status server",
        ]:
            self.assertIn(probe, command[-1])

    def test_unverifiable_nodes_fail_without_ssh(self):
        cases = [
            [],
            [self.node, self.node],
            [{**self.node, "Online": False}],
            [{**self.node, "ID": ""}],
            [{**self.node, "TailscaleIPs": []}],
            [{**self.node, "TailscaleIPs": ["not-an-ip"]}],
            [{**self.node, "DNSName": "kamino1-other.example.ts.net."}],
            [self.node, {**self.node, "DNSName": "kamino2.example.ts.net."}],
        ]
        for nodes in cases:
            with self.subTest(nodes=nodes), patch.object(fleet, "run") as run:
                result = fleet.verify_machines([self.machine], nodes)[0]
                self.assertEqual(result["status"], "fail")
                run.assert_not_called()

    def test_wrong_remote_identity_or_service_fails(self):
        for probe in [
            self.probe.replace("root", "ubuntu"),
            self.probe.replace("kamino1", "kamino2"),
            self.probe.replace("active", "inactive"),
            "root\nkamino1\n",
        ]:
            with patch.object(fleet, "run", return_value=probe):
                self.assertEqual(
                    fleet.verify_machines([self.machine], [self.node])[0]["status"],
                    "fail",
                )

    def test_ssh_error_and_timeout_do_not_leak_output(self):
        for error in [
            subprocess.CalledProcessError(255, "ssh", stderr="private-data"),
            subprocess.TimeoutExpired("ssh", 20),
            FileNotFoundError(),
        ]:
            with patch.object(fleet, "run", side_effect=error):
                result = fleet.verify_machines([self.machine], [self.node])[0]
                self.assertEqual(result["status"], "fail")
                self.assertNotIn("private-data", json.dumps(result))

    def test_tailscale_requires_authentication_and_valid_peer_shape(self):
        for status in [
            [],
            {"BackendState": "NeedsLogin"},
            {"BackendState": "Running", "Peer": [1]},
        ]:
            with patch.object(fleet, "run", return_value=json.dumps(status)):
                with self.assertRaises(ValueError):
                    fleet.read_nodes()

    def test_cli_list_offline_and_verify_missing(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "inventory.json"
            path.write_text(json.dumps({"machines": [self.machine]}))
            with (
                patch.object(fleet, "run") as run,
                contextlib.redirect_stdout(io.StringIO()) as out,
            ):
                self.assertEqual(
                    fleet.main(["--inventory", str(path), "list", "--json"]), 0
                )
                run.assert_not_called()
                self.assertEqual(json.loads(out.getvalue())[0]["status"], "declared")
            with (
                patch.object(fleet, "read_nodes", return_value=[]),
                contextlib.redirect_stdout(io.StringIO()),
            ):
                self.assertEqual(fleet.main(["--inventory", str(path), "verify"]), 1)
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(
                    fleet.main(["--inventory", str(path), "list", "no-match"]), 2
                )
