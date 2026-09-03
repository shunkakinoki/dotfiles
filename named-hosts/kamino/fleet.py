"""List the generated Kamino family or verify its enrolled SSH endpoints."""

import argparse
import fnmatch
import ipaddress
import json
import subprocess
import sys
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


def run(command):
    return subprocess.run(
        command,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        timeout=20,
        check=True,
    ).stdout


def select_machines(inventory, pattern):
    machines = [
        machine
        for machine in inventory["machines"]
        if fnmatch.fnmatchcase(machine["name"], pattern)
    ]
    if not machines:
        raise ValueError(f"No declared machines match {pattern!r}")
    return machines


def read_nodes():
    status = json.loads(run(["tailscale", "status", "--json"]))
    if not isinstance(status, dict) or status.get("BackendState") != "Running":
        raise ValueError("Tailscale is not running and authenticated")
    peers = status.get("Peer") or {}
    if not isinstance(peers, dict):
        raise ValueError("Invalid Tailscale peer inventory")
    nodes = list(peers.values())
    if status.get("Self"):
        nodes.append(status["Self"])
    if any(not isinstance(node, dict) for node in nodes):
        raise ValueError("Invalid Tailscale node record")
    return nodes


def verify_machine(machine, nodes, node_ids):
    result = {**machine, "status": "fail", "node_id": None}
    matches = [
        node
        for node in nodes
        if str(node.get("DNSName", "")).rstrip(".").lower() == machine["hostname"]
    ]
    if len(matches) != 1:
        result["reason"] = (
            "missing or not visible" if not matches else "duplicate DNS name"
        )
        return result
    node = matches[0]
    node_id = node.get("ID")
    if not isinstance(node_id, str) or not node_id or node_ids[node_id] != 1:
        result["reason"] = "missing or duplicate Tailscale device ID"
        return result
    result["node_id"] = node_id
    if node.get("Online") is not True:
        result["reason"] = "offline"
        return result
    addresses = node.get("TailscaleIPs")
    try:
        address = str(ipaddress.ip_address(addresses[0]))
    except (ValueError, TypeError, IndexError, KeyError):
        result["reason"] = "missing or invalid Tailscale IP"
        return result
    try:
        # Connect to the observed node IP, but authenticate its declared DNS name.
        # Do not accept new keys or reuse a previously authenticated SSH socket.
        output = run(
            [
                "ssh",
                "-o",
                "BatchMode=yes",
                "-o",
                "StrictHostKeyChecking=yes",
                "-o",
                "UpdateHostKeys=no",
                "-o",
                "ConnectTimeout=10",
                "-o",
                "ConnectionAttempts=1",
                "-o",
                "ControlPath=none",
                "-o",
                f"HostName={address}",
                "-o",
                f"HostKeyAlias={machine['hostname']}",
                f"{machine['user']}@{machine['hostname']}",
                "/bin/sh -c 'export XDG_RUNTIME_DIR=/run/user/0; "
                "id -un && hostname && "
                "/root/.nix-profile/bin/herdr --version && "
                "/root/.nix-profile/bin/tmux -V && "
                "/root/.nix-profile/bin/zellij --version && "
                "/usr/bin/systemctl --user is-active herdr-server && "
                "/root/.nix-profile/bin/herdr status server >/dev/null'",
            ]
        ).splitlines()
    except (OSError, subprocess.SubprocessError):
        result["reason"] = (
            "SSH or tools/service probe failed; check login, host key and Herdr"
        )
        return result
    if len(output) != 6 or output[0] != machine["user"]:
        result["reason"] = "unexpected SSH user or probe output"
    elif output[1].split(".", 1)[0] != machine["name"]:
        result["reason"] = "SSH hostname differs from declaration"
    elif output[5] != "active" or not all(output[2:5]):
        result["reason"] = "tools or Herdr service not healthy"
    else:
        result.update(
            status="pass",
            reason="identity, Herdr server, tmux and Zellij verified",
            versions=output[2:5],
        )
    return result


def verify_machines(machines, nodes):
    node_ids = Counter(node["ID"] for node in nodes if isinstance(node.get("ID"), str))
    with ThreadPoolExecutor(max_workers=8) as executor:
        return list(
            executor.map(
                lambda machine: verify_machine(machine, nodes, node_ids), machines
            )
        )


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", required=True, type=Path)
    parser.add_argument("command", choices=["list", "verify"])
    parser.add_argument("pattern", nargs="?", default="kamino*")
    parser.add_argument("--json", action="store_true", dest="as_json")
    args = parser.parse_args(argv)
    try:
        inventory = json.loads(args.inventory.read_text())
        machines = select_machines(inventory, args.pattern)
        if args.command == "list":
            results = [{**machine, "status": "declared"} for machine in machines]
        else:
            results = verify_machines(machines, read_nodes())
    except (
        OSError,
        ValueError,
        KeyError,
        TypeError,
        subprocess.SubprocessError,
    ) as error:
        # Captured command output may contain private tailnet metadata; never echo it.
        message = str(error) if isinstance(error, ValueError) else type(error).__name__
        print(f"kamino-fleet: {message}", file=sys.stderr)
        return 2
    if args.as_json:
        print(json.dumps(results))
    else:
        for result in results:
            detail = result.get("reason", result["hostname"])
            print(f"{result['name']}\t{result['status']}\t{detail}")
    return int(any(result["status"] == "fail" for result in results))


if __name__ == "__main__":
    sys.exit(main())
