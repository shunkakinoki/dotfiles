# Kamino

`kamino` is the root-managed x86_64 Ubuntu VPS. Its Home Manager target is
`homeConfigurations.kamino`, its account is `root`, and its home and checkout are
`/root` and `/root/dotfiles`. It uses the common CLI environment and a persistent
Herdr user service, without Kyber's Kubernetes, gateway, or root-SSH hardening.

This configuration does not provision a VPS, enroll it in Tailscale, authorize
SSH keys, or create worker containers. Those are separate operations. A successful
evaluation or CI build does not prove that the pending VPS is reachable.

## Names are device identities, not a load balancer

| Name | Intended endpoint | Configured here |
| --- | --- | --- |
| `kamino` | VPS host, `root` login | Yes |
| `kamino1` through `kamino8` | Separate AI worker containers | No |
| `kamino9` and `kamino10` | Separate CI containers | No |

The host's full name is `kamino.tail950b36.ts.net`. Registering the host does not
create DNS records for its containers. Each future container needs its own
Tailscale client (in the container or a network-sharing sidecar), unique hostname,
persistent Tailscale state, and SSH server. They can share one VPS/public IP while
having separate Tailscale IPs. Never copy the host's Tailscale state into an image
or share one state volume between devices.

[MagicDNS](https://tailscale.com/docs/features/magicdns) registers each device's
name. The official [Docker parameters](https://tailscale.com/docs/features/containers/docker/docker-params)
include `TS_HOSTNAME` for the name and `TS_STATE_DIR` for identity persistence.
An SSH alias alone cannot create a Tailscale device. Do not apply `HOST=kamino`
inside a numbered container: this profile would advertise the host's name.

## Offline checks, before the VPS is available

Run these from the dotfiles checkout containing this change. They work on macOS
as well as Linux and do not activate anything:

```sh
nix eval --impure --raw .#homeConfigurations.kamino.config.home.username
# root
nix eval --impure --raw .#homeConfigurations.kamino.config.home.homeDirectory
# /root
nix eval --impure --raw .#checks.x86_64-linux.eval-home-kamino.drvPath
shellspec spec/make_build_host_resolution_spec.sh spec/ssh_config_spec.sh
```

The evaluation check asserts the root home, SSH endpoint, Tailscale hostname,
Herdr unit, and absence of Kyber-only service activation. The existing Linux CI
job also builds the Kamino activation package. Evaluation is not a Linux build.

## First activation, after the VPS is ready

Use the provider console or its supplied IP first. Verify the SSH host-key
fingerprint through that console before accepting it. Keep the console and an
existing SSH session available until a second session works over Tailscale.
Install the intended public SSH key for `root` without replacing existing keys;
this profile does not change the provider's SSH authentication policy.

Prerequisites: x86_64 Ubuntu with systemd, Git, Make, Bash, sudo, a working Nix
installation with flakes enabled, and a root user systemd bus (Ubuntu's
`dbus-user-session` package). Use the repository's setup instructions for Nix.
Clone this repository into `/root/dotfiles` if absent, and check out the reviewed
revision. Do not overwrite an existing checkout or its untracked `.env`.

Before switching, authenticate Tailscale interactively and confirm its assigned
name is exactly `kamino`. The shared Tailscale activation runs `tailscale up`;
without prior authentication it can wait for login. Use the already installed
Tailscale client, with these same flags:

```sh
tailscale up --hostname=kamino --accept-dns=false --ssh=false
tailscale status --json | jq '.Self | {DNSName, TailscaleIPs, Online}'
```

Tailscale installation/authentication is a bootstrap prerequisite, not something
to hide inside an unattended switch. MagicDNS must be enabled in the tailnet;
clients resolving these names must use Tailscale DNS. `--accept-dns=false` on the
VPS preserves its resolver choice; it does not prevent publishing its DNS name.
Access rules must allow your client to reach Kamino's TCP port 22. This setup uses
ordinary OpenSSH over Tailscale, not Tailscale SSH (`--ssh=false`).

On the VPS, as root:

```sh
test "$(id -u)" = 0
test "$HOME" = /root
test "$(uname -m)" = x86_64
hostnamectl set-hostname kamino
loginctl enable-linger root
```

Reconnect as root to obtain a fresh systemd user session, then verify the bus
before activation:

```sh
systemctl --user show-environment >/dev/null
cd /root/dotfiles
make build HOST=kamino
make nix-switch HOST=kamino
```

Run switch only if build succeeds. `make nix-switch` is the focused Home Manager
activation target; `make switch` includes additional dotfiles post-activation
tasks. Do not run either Kamino switch command on your Mac. The shared Tailscale
module installs system units and a sudoers fragment during activation, so the
host's existing Tailscale setup must be reviewed before that first switch.

## Verify the host, one layer at a time

On Kamino:

```sh
id -un                              # root
hostname                            # kamino
systemctl is-active tailscaled      # active
tailscale status --json | jq '.Self | {DNSName, TailscaleIPs, Online}'
systemctl --user is-enabled herdr-server
systemctl --user show herdr-server -p ActiveState -p SubState -p MainPID
herdr status server
home-manager generations
readlink -f /root/dotfiles/result
```

Expect `kamino.tail950b36.ts.net.`, an online Tailscale identity, an enabled Herdr
unit with `ActiveState=active`, `SubState=running`, a nonzero PID, and a successful
Herdr server response. Compare the current Home Manager generation's store path
with the built `result`. Merely having the executable or a running process is not
an application-health check.

After applying the SSH configuration on your client using that client's normal
build/switch workflow:

```sh
ssh -G kamino | grep -E '^(hostname|user) '
# user root
# hostname kamino.tail950b36.ts.net
tailscale ping kamino
ssh -o BatchMode=yes kamino 'id -un; hostname'
herdr --remote kamino
```

Before the client configuration is activated, use
`ssh root@kamino.tail950b36.ts.net` explicitly. Verify the host-key fingerprint;
never bypass host-key checking to make this test pass. Root access controls the
entire VPS, not an isolated container.

When the numbered fleet is implemented, repeat `tailscale ping kamino1` and
`ssh root@kamino1 'id -un; hostname'` for each name through `kamino10` (from a
MagicDNS-enabled client). Check the Tailscale console for distinct device IDs and
IPs, and verify those identities survive individual container restarts. Until
then these names are a naming plan, not functioning endpoints.

## Environment and recovery

Herdr reads the optional `/root/dotfiles/.env` at service start via systemd's
`EnvironmentFile`. It must contain systemd-compatible variable assignments, not
shell commands or `export` statements. This PR neither copies credentials nor
changes hydration. A missing file does not block startup; authenticated worker
operations still need their own credentials. Do not display the file or service
environment as verification. Restart the Herdr service deliberately after a
credential change; that interrupts its active sessions.

For recovery, keep console access and the previous Home Manager generation.
Use `home-manager generations` to locate its activation script. Home Manager
rollback alone does not undo system files installed by activation hooks; review
the Tailscale system units and sudoers changes separately. No provider firewall,
SSH daemon, or container-fleet policy is installed by this host profile.
