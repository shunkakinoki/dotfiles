#!/usr/bin/env bash
# Prepare a dedicated, empty block device for Kyber's containerd filesystem.
set -euo pipefail

DEVICE="${1:-}"
CONFIRMATION="${2:-}"
MOUNT_LABEL="k3s-containerd"
FILESYSTEM_UUID="90f29a7b-38ff-460b-b534-92a02f1412ec"
MOUNT_POINT="/var/lib/rancher/k3s/agent/containerd"

if [ -z "$DEVICE" ] || [ "$CONFIRMATION" != "--confirm-wipe" ]; then
  echo "Usage: $0 /dev/<device> --confirm-wipe" >&2
  exit 2
fi

if [ ! -b "$DEVICE" ]; then
  echo "Refusing to format a path that is not a block device: $DEVICE" >&2
  exit 1
fi
resolved_device="$(readlink -f "$DEVICE")"

if systemctl is-active --quiet k3s; then
  echo "Refusing to prepare the containerd disk while k3s is running" >&2
  echo "Stop k3s first: sudo systemctl stop k3s" >&2
  exit 1
fi

if lsblk --noheadings --raw --output MOUNTPOINT "$DEVICE" | grep -q '[^[:space:]]'; then
  echo "Refusing to format a device with mounted filesystems: $DEVICE" >&2
  exit 1
fi

if findmnt --mountpoint "$MOUNT_POINT" >/dev/null 2>&1; then
  echo "Refusing to replace the filesystem already mounted at $MOUNT_POINT" >&2
  exit 1
fi

existing_uuid_device=""
if [ -e "/dev/disk/by-uuid/$FILESYSTEM_UUID" ]; then
  existing_uuid_device="$(readlink -f "/dev/disk/by-uuid/$FILESYSTEM_UUID")"
  if [ "$existing_uuid_device" != "$resolved_device" ]; then
    echo "Refusing to create duplicate filesystem UUID $FILESYSTEM_UUID; it already exists on $existing_uuid_device" >&2
    exit 1
  fi
fi

if [ -d "$MOUNT_POINT" ]; then
  if ! first_entry="$(sudo find "$MOUNT_POINT" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)"; then
    echo "Refusing to prepare the disk because $MOUNT_POINT could not be inspected" >&2
    exit 1
  fi
  if [ -n "$first_entry" ]; then
    echo "Refusing to hide a non-empty containerd directory at $MOUNT_POINT" >&2
    exit 1
  fi
fi

current_uuid="$(sudo blkid --match-tag UUID --output value "$DEVICE" 2>/dev/null || true)"
current_fs_type="$(sudo blkid --match-tag TYPE --output value "$DEVICE" 2>/dev/null || true)"

if [ "$current_uuid" = "$FILESYSTEM_UUID" ]; then
  if [ "$current_fs_type" != "ext4" ]; then
    echo "Refusing to reuse $DEVICE because UUID $FILESYSTEM_UUID is not on an ext4 filesystem" >&2
    exit 1
  fi
  echo "Reusing $DEVICE with its existing pinned ext4 filesystem UUID"
else
  sudo wipefs --all "$DEVICE"
  sudo mkfs.ext4 -F -L "$MOUNT_LABEL" -U "$FILESYSTEM_UUID" "$DEVICE"
fi

sudo udevadm settle
prepared_uuid="$(sudo blkid --match-tag UUID --output value "$DEVICE")"
prepared_fs_type="$(sudo blkid --match-tag TYPE --output value "$DEVICE")"
if [ "$prepared_uuid" != "$FILESYSTEM_UUID" ] || [ "$prepared_fs_type" != "ext4" ]; then
  echo "Prepared filesystem identity mismatch on $DEVICE: UUID=$prepared_uuid TYPE=$prepared_fs_type" >&2
  exit 1
fi
if [ ! -e "/dev/disk/by-uuid/$FILESYSTEM_UUID" ]; then
  echo "Pinned filesystem UUID path was not created: /dev/disk/by-uuid/$FILESYSTEM_UUID" >&2
  exit 1
fi

sudo mkdir -p "$MOUNT_POINT"
sudo mount "/dev/disk/by-uuid/$FILESYSTEM_UUID" "$MOUNT_POINT"

mounted_source="$(findmnt --noheadings --output SOURCE --target "$MOUNT_POINT")"
resolved_source="$(readlink -f "$mounted_source")"
if [ "$resolved_source" != "$resolved_device" ]; then
  echo "Unexpected device mounted at $MOUNT_POINT: $mounted_source" >&2
  exit 1
fi

echo "Prepared $DEVICE as UUID $FILESYSTEM_UUID ($MOUNT_LABEL) and mounted it at $MOUNT_POINT"
echo "Run make switch to install the persistent systemd mount dependency"
