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
kyber  # Fish abbreviation that runs: ssh ubuntu@kyber
```

## k3s Containerd SSD

Kyber mounts a dedicated ext4 filesystem labeled `k3s-containerd` at
`/var/lib/rancher/k3s/agent/containerd`. The generated `k3s.service` requires
that mount, so a missing SSD fails closed instead of silently writing images to
the root filesystem. Linux device letters are not stable across boots; the
systemd mount intentionally resolves the filesystem label rather than
hard-coding `/dev/sda`.

On a new or intentionally wiped host, prepare the empty containerd SSD before
the first `make switch`:

```bash
sudo systemctl stop k3s
./named-hosts/kyber/prepare-containerd-disk.sh /dev/sda --confirm-wipe
make switch
```

The preparation command destroys all data on the selected device. It refuses
to run while k3s is active, while any filesystem on the device is mounted, or
when the existing containerd directory is non-empty. Normal Home Manager
activation never formats disks.

Verify the persistent mount and service dependency after activation:

```bash
findmnt /var/lib/rancher/k3s/agent/containerd
systemctl is-enabled var-lib-rancher-k3s-agent-containerd.mount
systemctl show k3s -p Requires -p After
sudo systemctl restart k3s
findmnt /var/lib/rancher/k3s/agent/containerd
```

Persistent volumes remain outside the containerd SSD. In particular, an
unrestricted local-path PVC must not be treated as a hard capacity quota.

## k3s Disk Headroom

Host activation keeps the root ext4 reserved blocks at 1% and limits kubelet
to two parallel image pulls. Before containerd received a dedicated SSD,
Ubuntu's default 5% reserve on the 916 GiB root volume hid about 46 GiB from
kubelet and left too little usable headroom during overlapping rollouts.

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

For diagnosis, check filesystem headroom, I/O pressure, kubelet GC messages,
and CRI health before restarting services:

```bash
df -h / /var/lib/rancher/k3s/agent/containerd
cat /proc/pressure/io
sudo tune2fs -l "$(findmnt -n -o SOURCE /)" | grep -E 'Block count|Reserved block count'
sudo journalctl -u k3s --since '30 minutes ago' | grep -E 'image garbage collection|DiskPressure|deadline exceeded'
sudo k3s crictl info
```

An ordinary `systemctl restart k3s` intentionally preserves running containers
because the upstream unit uses `KillMode=process`. If containerd itself is
wedged, use the installed `k3s-killall.sh` once during an attended recovery,
then start k3s again. The helper preserves cluster data but terminates every
running workload, so it is not a timer or routine cleanup mechanism.

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
