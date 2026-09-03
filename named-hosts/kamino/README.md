# Kamino operations

## Installation and fleet verification

Run this **as root on each x86_64 Ubuntu machine** (systemd required):

```sh
curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/main/install.sh | HOST=kamino1 sh
```

`HOST=KAMINO1` also works and becomes `kamino1`. Use `kamino` for the parent VPS,
then `kamino1` through `kamino100` for separate machines. These profiles and SSH
aliases are generated from one [family declaration](fleet.nix);
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

## Offline validation

Run from the reviewed dotfiles checkout without activating a remote profile:

```sh
nix eval --impure --raw .#homeConfigurations.kamino100.config.home.username
# root
nix eval --impure --raw .#homeConfigurations.kamino100.config.home.homeDirectory
# /root
nix eval --impure --raw .#checks.x86_64-linux.eval-home-kamino100.drvPath
python3 -m unittest discover -s tests -p 'test_kamino*.py'
shellspec spec/install_spec.sh spec/make_build_host_resolution_spec.sh spec/ssh_config_spec.sh
```

The evaluation checks cover root identity, common tools/configs, SSH aliases,
upgrade targeting and absence of Kyber-only services. Linux CI builds the parent
and hundredth generated profile. Evaluation is not a successful Linux build;
neither is live activation proof.

## Reviewed revision and first activation

Use the provider console or supplied IP first. Keep console access and an
existing SSH session open until a second connection works over Tailscale.
Verify the root SSH host-key fingerprint through the console. Provision the
intended public authorized key without replacing existing keys.

The curl installer tracks main. To test a reviewed but unmerged revision, clone
the repository into `/root/dotfiles`, check out that revision, and run:

```sh
HOST=kamino1 make build
HOST=kamino1 make nix-switch
```

Run switch only after build succeeds, on the intended root/systemd Linux machine.
For an existing checkout, preserve its local changes and untracked dotenv.
Fresh minimal Ubuntu also needs `dbus-user-session`; the installer bootstraps it.
Activation sets the hostname, enables root lingering, starts the user manager
and applies the named service configuration. It configures Tailscale without
interactive enrollment; a fresh node still needs authentication.

MagicDNS must be enabled in the tailnet and client access rules must permit TCP
22. Server-side `--accept-dns=false` does not prevent publishing the node name.
The profile uses OpenSSH over Tailscale, not Tailscale SSH. Root on the parent VPS
controls the whole VPS, not an isolated worker.

## Runtime and persistence proof

Alongside `kamino-fleet verify kamino1`, check on the target:

```sh
XDG_RUNTIME_DIR=/run/user/0 systemctl --user show herdr-server -p ActiveState -p SubState -p MainPID
home-manager generations
readlink -f /root/dotfiles/result
```

Expect an active/running Herdr unit and nonzero PID. Compare the activated
generation with the built result. Attach interactively with Herdr, tmux and
Zellij to test real sessions. Later, with permission to restart that machine,
verify its Tailscale device ID and SSH host key remain unchanged and services
return healthy. Do not infer restart persistence from source configuration.

## Environment and recovery

Herdr reads optional `/root/dotfiles/.env` at service start using systemd's
`EnvironmentFile`. Use systemd-compatible assignments, not shell commands or
`export` statements. This change neither copies credentials nor alters
hydration. Missing credentials may prevent authenticated AI-worker operations,
even when the multiplexer itself works. Never display the file or service
environment as verification.

A deliberate Herdr service restart interrupts its active sessions. Keep console
access and the previous Home Manager generation for recovery. Home Manager
rollback does not undo hostname/lingering or system files installed by activation
hooks; review those and the Tailscale units separately. No new SSH daemon,
firewall policy, VPS or container runtime is provisioned here.
