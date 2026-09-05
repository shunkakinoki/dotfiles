# Kyber Host Configuration

Ubuntu Linux server managed via home-manager with Tailscale VPN.

## Initial Setup

On the Kyber server, run:

```bash
# 1. Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable --now tailscaled
sudo tailscale up

# 2. Install Nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux

# 3. Clone dotfiles
git clone https://github.com/shunkakinoki/dotfiles ~/dotfiles
cd ~/dotfiles

# 4. Apply configuration
make switch
```

## Managing Secrets

### Get Kyber's SSH public key

```bash
ssh ubuntu@kyber "cat ~/.ssh/id_ed25519.pub"
```

Add this key to `secrets.nix`, then encrypt secrets:

```bash
# Encrypt Tailscale auth key
make encrypt-key-kyber KEY_FILE=/path/to/tailscale-auth-key.txt

# Verify
make decrypt-key-kyber KEY_FILE=tailscale-auth
```

## SSH Access

Once Tailscale is set up:

```bash
kyber  # Fish abbreviation that runs: ssh kyber
```

Remote SSH should go through Tailscale. Latitude project firewall restricts
TCP/22 to `100.64.0.0/10`, and host activation drops new WAN ingress on the
public NIC (IPv4 + IPv6). Prefer keeping provider SG and host firewall aligned.

## Security Posture

Activation converges:

- WAN `iptables` / `ip6tables` chain (default-route NIC, override with
  `KYBER_PUBLIC_IF`) — established only, no public SSH
- `/etc/ssh/sshd_config.d/99-kyber-hardening.conf` — pubkey-only, no root,
  `AllowUsers ubuntu`
- OpenClaw gateway forced `--bind loopback`
- Tailscale `--advertise-exit-node` with `--ssh=false` (OpenSSH over Tailscale)

Still intentional / follow-up:

- Shared Galactica GitHub + GPG identity until per-host deploy keys exist
- Bootstrap still uses vendor `curl | sh` installers (verify checksums)
- Cluster-admin kubeconfig sync from Galactica remains break-glass style

## k3s Containerd SSD

Kyber mounts the dedicated ext4 filesystem with UUID
`90f29a7b-38ff-460b-b534-92a02f1412ec` at
`/var/lib/rancher/k3s/agent/containerd`. The generated `k3s.service` requires
that mount, so a missing SSD fails closed instead of silently writing images to
the root filesystem. Linux device letters and user-editable filesystem labels
are not stable identities; the systemd mount intentionally resolves the
verified filesystem UUID rather than hard-coding `/dev/sda`. The
`k3s-containerd` label remains only a human-readable diagnostic aid.

On a new or intentionally wiped host, prepare the empty containerd SSD before
the first `make switch`:

```bash
sudo systemctl stop k3s
./named-hosts/kyber/prepare-containerd-disk.sh /dev/sda --confirm-wipe
make switch
```

The preparation command destroys all data on the selected device unless it
already contains the expected ext4 UUID. It refuses to run while k3s is active,
while any filesystem on the device is mounted, when the existing containerd
directory is non-empty, or when the pinned UUID resolves to another device.
After formatting, it validates the filesystem type and UUID before mounting it.
Normal Home Manager activation never formats disks.

Verify the persistent mount and service dependency after activation:

```bash
findmnt /var/lib/rancher/k3s/agent/containerd
findmnt -n -o UUID /var/lib/rancher/k3s/agent/containerd
systemctl is-enabled var-lib-rancher-k3s-agent-containerd.mount
systemctl show k3s -p Requires -p After
sudo systemctl restart k3s
findmnt /var/lib/rancher/k3s/agent/containerd
```

Persistent volumes remain outside the containerd SSD. The SSD contains only
embedded containerd runtime state: image content, snapshots, metadata, and
temporary runtime data. K3s datastore paths and application PVCs, including
local-path provisioner volumes, remain on the root/storage filesystem. An
unrestricted local-path PVC must not be treated as a hard capacity quota.

## k3s Disk Headroom

Host activation keeps the root ext4 reserved blocks at 1%. Kubelet serializes
image pulls, begins image garbage collection at 70% usage, targets 60%, keeps a
50 GiB emergency reserve on the root (`nodefs`), and keeps 20% available on the
dedicated containerd (`imagefs`) filesystem. A percentage-based nodefs reserve
is intentionally avoided: 20% of Kyber's 916 GiB root volume is roughly 183
GiB, enough working headroom that eviction causes more harm than continued
operation. Before containerd received a dedicated SSD, Ubuntu's default 5%
reserve on the root volume hid about 46 GiB from kubelet and left too little
usable headroom during overlapping rollouts.

Kubelet owns image, container, and pod-sandbox garbage collection. Do not add a
separate `crictl` cleanup timer: deleting CRI objects behind kubelet can race
active pod lifecycle operations and leave container names or cgroups stuck.

The July 2026 incident was a disk-pressure feedback loop, not a slow Temporal
queue. The shared root image filesystem crossed kubelet's 85% image-GC
threshold during concurrent pulls. Kubelet attempted to reclaim tens of GiB
from a much smaller logical image cache while containerd and Kine were already
I/O-bound. CRI calls timed out, stale tasks accumulated, and Temporal workers
could not start new chat turns. The dedicated image filesystem removes that
contention from the control-plane disk; pull limits and free-space thresholds
remain defense in depth.

## August 2026 MagicDNS Outage

On 2026-08-19 Kyber rebooted and came back with Tailscale `CorpDNS=true`.
`tailscaled` overwrote `/etc/resolv.conf` with MagicDNS (`100.100.100.100`).
MagicDNS had no upstream resolvers, so every glibc lookup returned SERVFAIL
while ICMP and HTTPS-by-IP still worked. cliproxy stayed "running" but could
not hydrate auth from R2; k3s image pulls failed the same way. SSH over the
tailnet still worked because it does not need public DNS.

`--accept-dns=false` was already declared in `modules.tailscale.extraUpArgs`,
but `installSystemService` only installed `tailscaled`. The `tailscale-up`
oneshot existed only for user-level services, so the flags never applied after
boot. `tailscale set --accept-dns=false` also does not restore a previously
overwritten resolv.conf.

Recovery:

```bash
sudo tailscale set --accept-dns=false
sudo ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
systemctl --user restart cliproxyapi.service
```

Durability: `tailscale-up.service` now runs `extraUpArgs` after `tailscaled`
and re-links the systemd-resolved stub whenever `--accept-dns=false` is set.
Host health alerts if Tailscale rewrites resolv.conf or public lookups fail.

For diagnosis, check filesystem headroom, I/O pressure, kubelet GC messages,
and CRI health before restarting services:

```bash
df -h / /var/lib/rancher/k3s/agent/containerd
cat /proc/pressure/io
sudo tune2fs -l "$(findmnt -n -o SOURCE /)" | grep -E 'Block count|Reserved block count'
sudo journalctl -u k3s --since '30 minutes ago' | grep -E 'image garbage collection|DiskPressure|deadline exceeded'
sudo k3s crictl info
```

## Host Reliability Monitoring and Log Bounds

The Kyber activation installs native host controls rather than an external CRI
cleaner:

- journald stores at most 2 GiB persistently and 256 MiB at runtime, retains no
  entry longer than seven days, and keeps 10 GiB free;
- kubelet rotates each container log at 10 MiB and retains three files;
- `kyber-smartd.service` uses `smartd` to monitor all SMART-capable physical
  disks, including wear, reallocation, error trends, and the containerd SSD,
  and runs short and long self-tests;
- `kyber-host-health.timer` runs a read-only check every minute for five-minute
  I/O PSI, five consecutive samples of at least three D-state processes,
  root node-filesystem usage at 70% and absolute headroom, containerd
  image-filesystem usage/identity at 70%, remaining SSD write endurance, CRI
  probe latency, recent CRI lifecycle errors, and host DNS (Tailscale must not
  own `/etc/resolv.conf`).

The Herdr server runs in `herdr.slice`, which is never frozen: it is the
control plane for every lane and must keep answering API calls. Its pane
shells re-exec themselves into `orchestration.slice` through the kyber fish
init, so lane work, RoboRev, and their child processes share one disposable
slice that caps aggregate writes to 20 MB/s and aggregate tasks to 2,048.
When sustained host I/O PSI or D-state pressure crosses the health threshold
and the slice's own `io.pressure` or D-state count implicates it, the
host-health check records PSI, process/`wchan`, per-process I/O, cgroup I/O,
and recent k3s logs under `/run/kyber-host-health/evidence`, then freezes only
that disposable slice. Host pressure that the slice is not implicated in
(k3s, containerd, storage) leaves it running. It never freezes or restarts
k3s, containerd, or storage services. The slice thaws after five consecutive
pressure-free samples with a healthy CRI probe. Three freezes within an hour
raise `orchestration-circuit-breaker-flapping`, which means the slice re-trips
after every thaw and its top writers in the evidence captures need attention
rather than another auto-thaw.

Coding-agent hooks are the usual writer behind a flapping slice: every hook
event goes through `config/shared/hooks/traces-agent-hook.sh`, which bounds
the detached `traces share` uploads that the traces hook otherwise spawns
without limit (see [shared hooks](../../config/shared/hooks/README.md)).

This containment does not isolate ext4 journals. Kyber has two physical SSDs:
the root/PVC filesystem and the dedicated containerd filesystem. Moving k3s
server state therefore requires a third durable filesystem plus an attended
backup, integrity check, migration, and rollback exercise; do not simulate that
boundary with a bind mount on the root filesystem.

Alerts are deduplicated until recovery. They are written to the journal at
`daemon.alert` priority without interrupting logged-in terminals; a recovery
notice is written when a condition clears. These checks never remove containers,
pod sandboxes, shims, tasks, cgroups, or image content.

Verify the declarations and inspect current alerts after activation:

```bash
systemctl status kyber-smartd.service kyber-host-health.timer
systemctl list-timers kyber-host-health.timer
sudo journalctl -t kyber-host-health --since '24 hours ago'
sudo smartctl --scan-open
```

Run `sudo smartctl -a` against the physical device reported by
`smartctl --scan-open`; SMART data belongs to the SSD rather than its ext4
partition.

An ordinary `systemctl restart k3s` intentionally preserves running containers
because the upstream unit uses `KillMode=process`. If containerd itself is
wedged, use the installed `k3s-killall.sh` once during an attended recovery,
then start k3s again. The helper preserves cluster data but terminates every
running workload, so it is not a timer or routine cleanup mechanism.

## August 2026 CLIProxy and Kubernetes Pressure Outage

On 2026-08-19, `cliproxy.shunkakinoki.com` timed out while
`cliproxyapi.service` remained `active`. The proxy process and local `:8317`
listener were healthy; the host was not. A 17-hour-old SSH/Herdr session was
stuck in systemd's `closing` state with roughly 900-1,100 tasks. Concurrent
type-aware Oxlint/tsgolint validation peaked near 99 GiB and consumed dozens of
CPU cores. At the same time, root `nodefs` crossed the configured 20%-free
kubelet threshold despite retaining roughly 193 GiB. Kubelet evicted the
Cloudflare tunnel and ingress workloads, CRI and Kine calls timed out, and the
public proxy lost its origin path.

The incident escaped the existing checks because systemd tracked the live
Docker client rather than end-to-end reachability, the host-health timer had no
next trigger after activation, storage monitoring covered the dedicated
containerd filesystem but not root `nodefs`, and K3s passed systemd-resolved's
loopback stub into CoreDNS. After the cluster restarted, CoreDNS detected that
forwarding loop and could not bring the Cloudflare tunnel back online.

Recovery stopped only the runaway validation process groups, preserved the
Herdr/Codex session and dirty lanes, removed generated dependency data from
clean temporary lanes, applied the existing 30-day Nix GC policy, and let
kubelet clear `DiskPressure`. Durable controls now:

- schedule host health from timer activation and every minute thereafter;
- replace the oversized 20% nodefs threshold with an absolute 50 GiB emergency
  reserve and warn at 200 GiB available for attended cleanup;
- give pods a dedicated public upstream resolver file instead of the host's
  `127.0.0.53` systemd-resolved stub;
- weight the host system slice and managed user-service cgroup above interactive
  session scopes; and
- give CLIProxy maximum Docker CPU shares and block-I/O weight within the
  protected system slice.

During a recurrence, compare local `http://127.0.0.1:8317`, the public endpoint,
node conditions, session cgroups, and the Cloudflare tunnel pods before
restarting CLIProxy. An `active` unit plus a fast local response indicates an
origin-path or host-pressure incident, not a proxy daemon crash.

## SSH Key Management

### Automated Setup

This configuration uses:

- **agenix**: Encrypts and syncs the GitHub SSH key from galactica
- **keychain**: Manages ssh-agent and automatically loads SSH keys
- **Declarative deployment**: SSH keys are deployed during `make switch`

### Syncing SSH Keys from Galactica

#### On Galactica (one-time setup)

```bash
cd ~/dotfiles
git pull
make rekey-galactica
git add named-hosts/galactica/keys/
git commit -m "chore(agenix): rekey secrets for kyber access"
git push
```

#### On Kyber

```bash
cd ~/dotfiles
git pull
make switch
```

The GitHub SSH key will be automatically:

1. Decrypted from `named-hosts/galactica/keys/id_ed25519.age`
2. Deployed to `~/.ssh/id_ed25519_github`
3. Loaded into ssh-agent via keychain (if no passphrase)

### Adding Passphrase-Protected Keys

If the GitHub SSH key has a passphrase, add it manually:

```bash
sag  # Abbreviation for _ssh_add_github function

# Or manually
keychain --eval --quiet --confirm ~/.ssh/id_ed25519_github
```

### Verify GitHub Access

```bash
ssh -T git@github.com
# Expected: Hi username! You've successfully authenticated...
```

### Troubleshooting

**Key not deployed after `make switch`:**

```bash
# Check if key exists
ls -la ~/.ssh/id_ed25519_github

# Manually deploy if needed
age -d -i ~/.ssh/id_ed25519 -o ~/.ssh/id_ed25519_github \
  named-hosts/galactica/keys/id_ed25519.age
chmod 0600 ~/.ssh/id_ed25519_github
```

**GitHub authentication fails:**

```bash
# Check if key is in ssh-agent
ssh-add -l | grep github

# Add the key
sag
```
