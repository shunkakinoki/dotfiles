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

The installer runs the host-specific Tailscale enrollment command during its
`make nix-switch` phase:

```sh
tailscale up --hostname=kamino1 --accept-dns=false --ssh=false
```

On a fresh machine, follow the login URL printed during activation and choose
the intended tailnet. On an enrolled machine, the command reapplies the declared
name and preferences without creating a new device.

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
and applies the named service configuration. Its Tailscale phase runs
`tailscale up` directly, so a fresh node prompts for authentication as part of
`make nix-switch` instead of requiring a separate command afterward.

MagicDNS must be enabled in the tailnet and client access rules must permit TCP
22. Server-side `--accept-dns=false` does not prevent publishing the node name.
The profile uses OpenSSH over Tailscale, not Tailscale SSH. Root on the parent VPS
controls the whole VPS, not an isolated worker.

## Join the tailnet and publish the machine name

During installation, use the provider console on **kamino1**, not a client.
The final command below is run automatically by `make nix-switch`:

```sh
hostname                          # must print kamino1
systemctl is-active tailscaled    # must print active
tailscale up --hostname=kamino1 --accept-dns=false --ssh=false
```

Open the login URL printed by the switch in your browser and choose the intended
tailnet. If device
approval is enabled, approve this device in the Tailscale admin console. Check
its name and device ID there; the name must be exactly `kamino1`, not a suffixed
duplicate. Do not remove another machine to clear a collision: investigate which
device owns the name first. Repeat with a different declared name on each worker.

In the admin console's DNS page, enable MagicDNS and confirm that the tailnet
suffix matches `tailnet` in [fleet.nix](fleet.nix). Tailscale publishes the
name automatically after enrollment; there is no DNS zone or per-client hosts
file to sync. Git declarations alone do not register devices. See the upstream
[MagicDNS guide](https://tailscale.com/docs/features/magicdns) and
[`tailscale up` reference](https://tailscale.com/docs/reference/tailscale-cli/up).

Verify enrollment locally without displaying credentials:

```sh
tailscale status --json | jq '{BackendState, Self: (.Self | {ID, DNSName, Online, TailscaleIPs})}'
```

Expect `Running`, `Online: true` and `kamino1.tail950b36.ts.net.` with this fleet
declaration. Record the device ID and public SSH host-key fingerprint in your
private machine inventory. Subsequent dotfiles activation runs the same command
against the persisted Tailscale state and does not create a second device. If
authentication expires, reauthenticate this machine instead of
deleting its state. Do not use `--reset` or `--force-reauth` as routine sync steps.

## Connect from another client

### 1. Join the same tailnet and enable client DNS

Connect the client to the same tailnet using its existing Tailscale installation.
On Linux, enable DNS acceptance with `sudo tailscale set --accept-dns=true`;
in the macOS/Windows app, enable **Use Tailscale DNS settings**. This is a
**client** setting: Kamino servers deliberately keep DNS acceptance disabled.
Clients with their own managed DNS configuration need a working split-DNS route
for the tailnet suffix instead; do not overwrite that configuration blindly.

The tailnet's network access policy and the server firewall must allow this
client to reach the target's TCP port 22. Membership or a successful
`tailscale ping` alone does not prove that SSH access is allowed.

### 2. Sync dotfiles on the client, using the client's own host profile

For an existing clean checkout on its `main` branch:

```sh
cd ~/dotfiles
git status --short --branch
git pull --ff-only origin main
make build
make nix-switch
```

Stop if the checkout has local work or is not on `main`; preserve that work before
syncing. Run switch only after build succeeds. Known client names are detected
automatically. If an explicit `HOST` is needed, use that **client's** profile
(for example `galactica`, `kyber` or `matic`) for both commands. Never run
`HOST=kamino1` on your laptop or another existing host just to add an SSH alias.

The shared client module generates all declared Kamino aliases in one activation;
no separate `kamino1` entry is needed. Verify the effective configuration:

```sh
ssh -G kamino1 | awk '$1 == "hostname" || $1 == "user" { print }'
# user root
# hostname kamino1.tail950b36.ts.net
tailscale ping kamino1
```

`ssh -G` only checks local configuration. Without these dotfiles, use
`ssh root@kamino1` with working MagicDNS, or the explicit full name
`ssh root@kamino1.tail950b36.ts.net`. DNS does not select the remote username.
Inspect `~/.ssh/config.local` if a local override changes the generated target.

### 3. Authorize the client key and verify the server key

Use the provider's SSH-key provisioning facility or the existing console/admin
access to append the client's **public** key to `/root/.ssh/authorized_keys` on
the intended machine. Preserve existing keys; keep `/root/.ssh` mode `700` and
`authorized_keys` mode `600`, owned by root. Keep the private key on the client.
Managed clients select `~/.ssh/id_ed25519` by default; authorize its `.pub` file
or use an explicit, locally configured key.
The existing OpenSSH daemon must permit root public-key login; do not enable
password login or disable host-key checking to make verification pass.

Obtain the server's public host-key fingerprint through the trusted console:

```sh
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Then, on the client, compare that fingerprint before accepting the first
connection. If the server presents a different key type, compare the matching
public host key through the console. A changed key needs investigation, not an
automatic known-hosts reset.

```sh
ssh kamino1
# In that session: id -un must print root; hostname must print kamino1.
exit
kamino-fleet verify kamino1
herdr --remote kamino1
ssh -t kamino1 'tmux new-session -A -s work'
ssh -t kamino1 'zellij attach -c work'
```

OpenSSH over Tailscale uses ordinary authorized keys and host-key trust. It does
not require enabling [Tailscale SSH](https://tailscale.com/docs/features/tailscale-ssh),
which is a separate authentication mode and remains disabled by this profile.

### Troubleshooting by layer

| Failure | Check |
| --- | --- |
| No device named `kamino1` | Enrollment, approval, correct tailnet, exact device name and online status. |
| Name does not resolve | MagicDNS, client DNS acceptance/split DNS, and the fleet's tailnet suffix. On macOS use SSH or `ping`, not `nslookup`, to test the system resolver. |
| SSH timeout or refused connection | Tailnet TCP-22 policy, host firewall, and the existing OpenSSH listener. |
| `Permission denied (publickey)` | Client key/agent, root authorized key, file ownership/modes and root public-key login policy. |
| Unknown or changed host key | Compare against the provider console before trusting it. |
| SSH works but fleet verification fails | Exact root/hostname identity, Herdr service, tool versions and duplicate Tailscale IDs. |

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
