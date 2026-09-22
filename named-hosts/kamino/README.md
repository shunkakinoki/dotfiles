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
tailscale up --hostname=kamino1 --accept-dns=true --ssh=true
```

On a fresh machine, follow the login URL printed during activation and choose
the intended tailnet. On an enrolled machine, the command reapplies the declared
name and preferences without creating a new device.

Host login uses Tailscale SSH, authorized by the tailnet policy as root. Activation
adds the declared Galactica, Kyber, and Matic public keys to root's
`authorized_keys`, preserving provider keys and other existing entries. It sets
the SSH directory/file permissions to `700`/`600` and does not copy private keys.
Clients with a different key still need that public key provisioned separately.
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

Fish also provides the same shortcuts as Kyber and Matic for `kamino` and
every numbered host through `kamino100`:

| Shortcut | Action |
| --- | --- |
| `kamino1` | Tailscale SSH login as root |
| `kamino1d` | Attach/create the tmux `desktop` session |
| `kamino1h` | Attach to Herdr (`herdr --remote kamino1`) |
| `kamino1m` | Attach/create the tmux `mobile` session |
| `kamino1z` | Attach/create the Zellij `desktop` session |

Replace `kamino1` with any declared fleet name. SSH and Herdr shortcuts forward
additional arguments. Apply your **client's** normal dotfiles profile and open a
new Fish shell to load these abbreviations; do not activate a Kamino server
profile on your laptop. Every SSH shortcut runs `tailscale ssh root@<name>`:
the tailnet policy only grants root, so omitting the user fails with
`tailnet policy does not permit you to SSH as user "<local user>"`. Session
shortcuts pass `-t` so tmux and Zellij get a terminal.

`tailscale ssh` checks the host key against the one the node advertises to the
coordination server, so no trust-on-first-use prompt is needed. The generated
`ssh kamino1` alias keeps `StrictHostKeyChecking=yes`.

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

Beads clients connect directly to Kyber SQL on port 3307. Herdr workers receive
that policy with local auto-start disabled and `BEADS_NODE_ID=kyber`. Kamino
hosts run no local Beads server or federation jobs. Provisioning never replaces
preserved stores; reconcile unpublished data into Kyber before changing routing.

Confirm the effective endpoint with `bd context --json` and authoritative reads
with `bd --readonly ready --json`. The existing fleet read monitor owns scheduled
health checks. A passing local replica read does not prove authority access;
unavailable or misrouted reads never mean an empty queue.

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

## T3 Connect

Each worker is provisioned for T3 Connect during `make nix-switch`. Activation
installs or repairs the T3 background service, then requests a publish-only
link by default. Publish-only workers are reached over Tailscale and get no
relay-managed Cloudflare tunnel.

The first activation on a machine without a stored credential adds `--headless`,
so the OAuth device-flow URL is printed in the switch output and waits for
approval. Approve it once per machine. Later switches reuse the stored
credential:

```sh
t3 connect link --headless --publish-only   # first run, interactive approval
t3 connect link --publish-only              # later runs, no prompt
```

Confirm the persisted state as root:

```sh
t3 connect status
t3 service status
```

`t3 connect status` reports enabled exposure and a stored credential; the link
itself is provisioned by the background server on start, so restart
`t3code.service` if it was already running when the link was requested.
Provisioning needs `t3` from the npm globals in `package.json`; when it is
absent the activation step skips with a message.

### Connect a client to the T3 server

A publish-only environment has no relay endpoint, so a "T3 Connect" entry for
a Kamino worker fails with `endpoint_provider_not_managed`. The relay also caps
managed tunnels at 3 per account. Instead, `t3code.service` publishes itself
over Tailscale Serve at `https://<name>.tail950b36.ts.net`
(`T3CODE_TAILSCALE_SERVE`). Mint a pairing link on the worker:

```sh
t3 pair --tailscale --ttl 1h
```

In the client, remove any "T3 Connect" entry for the worker, then add an
environment with that pairing link.

### Sign in with T3 Connect instead

Workers listed in `t3ManagedTunnelHosts` in `default.nix` (currently `kamino5`)
link with a relay-managed tunnel instead of `--publish-only`, so they appear
under T3 Connect after signing in. Each one uses one of the account's 3 managed
tunnels. After adding a host, run `make nix-switch` on it; if it was linked
publish-only before, relink it once:

```sh
t3 connect unlink
t3 connect link
systemctl --user restart t3code.service
```

## GPG signing

The shared Home Manager GPG module imports the existing agenix-encrypted signing
key on activation for all non-runner profiles. User profiles decrypt with
`~/.ssh/id_ed25519`; root profiles use `/etc/ssh/ssh_host_ed25519_key`.
Kamino therefore uses its existing server identity without copying an
administrator's private SSH key to workers.

GPG recipients come from the shared `named-hosts/pubkeys.nix` registry. Enroll each
new machine's public key there and run `make rekey-galactica` from an authorized
operator checkout before activating that machine. A declared Kamino hostname alone
does not grant access to encrypted secrets. The GitHub SSH secret keeps its existing
recipient list. GPG uses the existing signing identity and GitHub registration.

After the reviewed configuration and rekeyed ciphertext are deployed, run the
normal host build/switch, then verify as root:

```sh
gpg --list-secret-keys --keyid-format LONG
echo test | gpg --clearsign | gpg --verify
```

Passphrase-protected keys retain their existing agent/pinentry behavior; importing
a key does not provide an unattended unlock after reboot.

## Offline validation

Run from the reviewed dotfiles checkout without activating a remote profile:

```sh
nix eval --impure --raw .#homeConfigurations.kamino100.config.home.username
# root
nix eval --impure --raw .#homeConfigurations.kamino100.config.home.homeDirectory
# /root
nix eval --impure --raw .#checks.x86_64-linux.eval-home-kamino100.drvPath
shellspec spec/kamino_fleet_spec.sh
shellspec spec/install_spec.sh spec/make_build_host_resolution_spec.sh spec/ssh_config_spec.sh
```

The evaluation checks cover root identity, common tools/configs, SSH aliases,
upgrade targeting, direct Beads authority routing, and absence of local SQL,
federation, and Linear reconciliation services. Linux CI builds the parent
and hundredth generated profile. Evaluation is not a successful Linux build;
neither is live activation proof.

## Reviewed revision and first activation

Use the provider console or supplied IP first. Keep console access and an
existing SSH session open until a second connection works over Tailscale.
The declared core-host public keys are installed during activation. Provision any
additional administrator public key without replacing existing entries. For
independent first-use verification, obtain the SSH host-key fingerprint through
the console before connecting.

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

MagicDNS must be enabled in the tailnet and the tailnet policy must grant
Tailscale SSH as `root` to your clients. Managed servers and clients both keep
DNS acceptance enabled. Root on the parent VPS controls the whole VPS, not an
isolated worker.

## Join the tailnet and publish the machine name

During installation, use the provider console on **kamino1**, not a client.
The final command below is run automatically by `make nix-switch`:

```sh
hostname                          # must print kamino1
systemctl is-active tailscaled    # must print active
tailscale up --hostname=kamino1 --accept-dns=true --ssh=true
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
in the macOS/Windows app, enable **Use Tailscale DNS settings**. The managed
Kamino configuration also enables DNS acceptance. Verify that both public
domains and tailnet names resolve after enrollment.

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
`tailscale ssh root@kamino1`. DNS does not select the remote username.
Inspect `~/.ssh/config.local` if a local override changes the generated target.

### 3. Verify the login

Tailscale SSH authorizes by tailnet identity, not client keys. Activation still
installs the core-host keys declared by `named-hosts/ssh-authorized-keys.nix` into
`/root/.ssh/authorized_keys` as a fallback.

```sh
tailscale ssh root@kamino1
# In that session: id -un must print root; hostname must print kamino1.
exit
kamino-fleet verify kamino1
herdr --remote kamino1
tailscale ssh root@kamino1 -t 'tmux new-session -A -s work'
tailscale ssh root@kamino1 -t 'zellij attach -c work'
```

### Troubleshooting by layer

| Failure | Check |
| --- | --- |
| No device named `kamino1` | Enrollment, approval, correct tailnet, exact device name and online status. |
| Name does not resolve | MagicDNS, client DNS acceptance/split DNS, and the fleet's tailnet suffix. On macOS use SSH or `ping`, not `nslookup`, to test the system resolver. |
| `tailnet policy does not permit you to SSH as user` | Connect as `root@kamino1`; the policy only grants root. |
| SSH timeout or refused connection | Device online status, `--ssh=true` on the node, and the tailnet SSH policy. |
| Changed host key | The node was re-enrolled or its state cloned; investigate before trusting it. |
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
