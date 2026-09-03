#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != Linux ] || [ "$(hostname -s)" != kyber ] || [ "$(id -un)" != ubuntu ]; then
  echo "Run kyber-incus-setup as ubuntu on Kyber only." >&2
  exit 1
fi

sudo -n true
if ! command -v incus >/dev/null 2>&1 || ! command -v mkfs.btrfs >/dev/null 2>&1; then
  sudo -n apt-get update
  sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y incus incus-client btrfs-progs
fi
sudo -n systemctl enable --now incus.service

# Always address the local daemon, regardless of the invoking user's remotes.
incus_local() {
  sudo -n env INCUS_SOCKET=/var/lib/incus/unix.socket incus --force-local --project default "$@"
}

# Preseed can update resources. Refuse to adopt an unrelated resource with a
# matching name, or hide its API error by treating it as a missing resource.
for kind in storage network project profile; do
  name=crabbox
  [ "$kind" != network ] || name=incus-crabbox
  inventory="$(incus_local "$kind" list --format=json)"
  if ! jq -e --arg name "$name" '
    all(.[]; .name != $name or .config["user.dotfiles"] == "kyber-crabbox")
  ' <<<"$inventory" >/dev/null; then
    echo "Refusing unmanaged Incus $kind $name." >&2
    exit 1
  fi
done

# Refuse to take over an existing route on another interface. The native
# preseed owns the address, and reapplying it to our own bridge is allowed.
routes="$(ip -4 route show 10.203.0.0/24)"
if printf '%s\n' "$routes" | grep -v ' dev incus-crabbox ' | grep -q .; then
  echo "10.203.0.0/24 is already routed outside incus-crabbox." >&2
  exit 1
fi

incus_local admin init --preseed < '@preseed@'

sudo -n install -m 0755 '@networkScript@' /usr/local/sbin/kyber-incus-network
sudo -n install -m 0644 '@networkService@' /etc/systemd/system/kyber-incus-network.service
sudo -n systemctl daemon-reload
sudo -n systemctl enable kyber-incus-network.service
sudo -n systemctl restart kyber-incus-network.service

# This is root-equivalent Incus administration, for the existing host operator
# only. New SSH sessions acquire the group; no daemon or user-manager restart.
if ! id -nG ubuntu | tr ' ' '\n' | grep -qx incus-admin; then
  sudo -n usermod -aG incus-admin ubuntu
fi
echo "Incus pilot configured. Open a new SSH session, then run crabbox doctor --provider incus."
