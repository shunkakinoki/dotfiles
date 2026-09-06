# Incus pilot on Kyber

Kyber's Home Manager profile installs `~/.config/crabbox/config.yaml` with
`provider: incus` and a `kyber-incus-setup` command. Other hosts are unchanged.
Incus is a direct CLI provider, not a backend for the Crabbox Node coordinator
or its browser portal. This does not change any repository's `ci:ship` routing.
Repo configuration, environment variables, and explicit flags override these
user defaults; pass `--provider incus` when the repo selects another provider.

## Install and activate

On Kyber, from the reviewed dotfiles revision:

```sh
cd ~/dotfiles
HOST=kyber make build
HOST=kyber make nix-switch
kyber-incus-setup
```

The setup command requires non-interactive sudo and refuses other hosts or
users. It installs Ubuntu's native `incus`, `incus-client`, and `btrfs-progs`
packages without adding a package repository. Ubuntu APT owns their security
updates. It enables Incus and applies the checked-in `preseed.yaml`; subsequent
runs reapply the same named resources, refusing unmarked name collisions.
It does not delete existing instances or modify the default Incus profile.

Setup adds `ubuntu` to `incus-admin`, which grants **root-equivalent host
authority**. Only the host operator gets this access; guests do not receive the
Incus socket. Reconnect with `ssh kyber` after setup to acquire the new group.
Existing long-lived Herdr sessions must be restarted separately before they
inherit group membership; setup does not interrupt those sessions.

## Pilot boundaries

| Setting | Value |
| --- | --- |
| Project / profile | `crabbox` / `crabbox` |
| Maximum existing instances | 2, including stopped instances |
| Per container | 4 CPUs, 8 GiB RAM, 1,024 processes |
| Project CPU / memory budget | 8 CPUs / 16 GiB RAM |
| Storage | 64 GiB Btrfs loop-backed pool; 24 GiB root quota per container |
| Per-container write limit | 10 MiB/s |
| Network | `incus-crabbox`, `10.203.0.1/24`, IPv4 NAT |
| Management | Local Unix socket only; no HTTPS listener configured |
| Guest image | Ubuntu 24.04 cloud image |

The pool is a file under Incus storage, **not a physical disk to format**. The
64 GiB pool bounds its guest/image storage, not all Incus logs, backups, or host
usage. Btrfs per-container quotas are not a hostile-tenant security boundary.
Containers share Kyber's kernel and can reach host services: use trusted work
only. Privileged containers, nesting, host bind mounts, and VMs are not enabled;
Docker-in-Docker validation is outside this first pilot.

The bridge is separate from K3s and Docker networks. A systemd oneshot permits
only bridge-to-uplink forwarding and established return traffic through
`DOCKER-USER`, including after Docker/Incus restarts. It does not open public
ports or change Docker's global forwarding policy. Incus handles bridge NAT,
DHCP, and DNS. Verify connectivity before treating the pilot as ready.

## Verify and try two concurrent boxes

In the new SSH session, from the repository you intend to sync:

```sh
id -nG
systemctl is-active incus kyber-incus-network
incus project show crabbox
incus profile show crabbox
crabbox config show --provider incus
crabbox doctor --provider incus
```

After doctor passes, create two separate leases. Each command prints a lease
ID; retain both IDs for explicit cleanup, including if bootstrap fails:

```sh
crabbox warmup --provider incus --slug kyber-smoke-1
crabbox warmup --provider incus --slug kyber-smoke-2
incus list --project crabbox
```

Use each printed ID in a separate terminal to verify sync and execution:

```sh
crabbox run --provider incus --id <lease-id> -- sh -c 'hostname; id; getent hosts github.com; test -d .git'
```

The containers use separate bridge IPs with port 22; there is no shared host
proxy port to collide. They are not automatically named Tailscale machines.
Release only the two IDs created by this smoke test:

```sh
crabbox stop --provider incus <first-lease-id>
crabbox stop --provider incus <second-lease-id>
incus list --project crabbox
```

Default release deletes the instance and frees its slot. There is no daily
start quota configured here, but the two-instance cap still applies. Raise it
in `preseed.yaml` only after measuring CPU, memory, disk, and I/O contention.
Removing the Home Manager import alone does not uninstall Incus or destroy its
data; retirement requires an explicit inventory and cleanup operation.

References: [Crabbox Incus provider](https://crabbox.sh/providers/incus.html),
[Incus initialization](https://linuxcontainers.org/incus/docs/main/howto/initialize/),
[Docker coexistence](https://linuxcontainers.org/incus/docs/main/howto/network_bridge_firewalld/#prevent-connectivity-issues-with-incus-and-docker).
