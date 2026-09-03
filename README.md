# Dotfiles

## Installation

```bash
 curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/main/install.sh | sh
```

To pin a named host (skips hostname auto-detection):

```bash
 curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/main/install.sh | HOST={NAMED_HOST_HERE} sh
```

For troubleshooting and frequently asked questions, see [FAQ.md](./FAQ.md).

For default and fallback model assignments per harness, see [MODELS.md](./MODELS.md).

### Kamino fleet

Run this **as root on each x86_64 Ubuntu machine** (systemd required):

```sh
curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/main/install.sh | HOST=kamino1 sh
```

`HOST=KAMINO1` also works and becomes `kamino1`. Use `kamino` for the parent VPS,
then `kamino1` through `kamino100` for separate machines. These profiles and SSH
aliases are generated from one [family declaration](named-hosts/kamino/fleet.nix);
change its `count` to grow the namespace, not one file per machine. Declaring a
name does **not** create or allocate a VPS/container. Give each machine a unique
name at provisioning time; the installer does not allocate names automatically.

Every profile installs the shared Herdr, tmux and Zellij binaries/configuration,
sets the OS hostname, starts the root Herdr user service with login lingering,
and keeps its named profile in the automatic dotfiles upgrade path. Reinstallation
refuses to change an already-installed Kamino identity. Plain Docker containers
without systemd are rejected; this is not a container deployment command.

The installer starts Tailscale and sets the node name without waiting for login.
On a fresh machine, enroll it once (or provision authentication separately):

```sh
tailscale up --hostname=kamino1 --accept-dns=false --ssh=false
```

This keeps the existing OpenSSH server/login policy, not Tailscale SSH. Provision
your root authorized key separately. Never put authentication keys in this command
or in the Nix declaration. The install command does not distribute credentials.
Preserve each machine's `/var/lib/tailscale`, `/etc/ssh`, `/etc/machine-id`, and
`/root` across restart/recreation. Never clone enrolled Tailscale state or SSH
private host keys into a second machine. DNS names alone are not cryptographic
machine identities.

After applying these dotfiles on your client, connect using the generated aliases:

```sh
ssh kamino1
herdr --remote kamino1
ssh -t kamino2 'tmux new-session -A -s work'
ssh -t kamino3 'zellij attach -c work'
```

On first SSH access, compare the presented host-key fingerprint with the VPS
console before accepting it. The verifier deliberately will not accept unknown
or changed SSH keys automatically.

```sh
kamino-fleet list 'kamino*'                 # declared names, not running machines
kamino-fleet verify kamino1                # check one installed machine
kamino-fleet verify 'kamino[1-8]' --json    # worker group
kamino-fleet verify 'kamino*'              # all declared names must be present
```

Verification requires an authenticated Tailscale client with visibility/access to
the targets. It checks unique device IDs, exact tailnet DNS names, online state,
trusted SSH, root login, the OS hostname, tool versions and the Herdr server.
Checks run with at most eight concurrent SSH probes. Missing, offline, duplicate,
untrusted, or unhealthy machines fail; an empty selector also fails. With only a
few machines deployed, select those names rather than verifying all 101 declared
names. Inspect returned IDs against your enrollment records if checking whether a
machine was replaced: the verifier does not maintain a device-ID registry.

Local service checks on each machine:

```sh
hostname
systemctl is-active tailscaled
XDG_RUNTIME_DIR=/run/user/0 systemctl --user is-active herdr-server
herdr status server
tmux -V
zellij --version
```

Live deployment/SSH/session verification must be performed once the VPS and
machines exist; evaluating or building a profile is not runtime proof.

## Credits

See [REFERENCES.md](./REFERENCES.md) for more information.
