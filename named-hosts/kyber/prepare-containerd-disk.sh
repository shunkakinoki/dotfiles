#!/usr/bin/env bash
# Prepare a dedicated, empty block device for Kyber's containerd filesystem.
set -euo pipefail

DEVICE="${1:-}"
CONFIRMATION="${2:-}"
MOUNT_LABEL="k3s-containerd"
MOUNT_POINT="/var/lib/rancher/k3s/agent/containerd"

if [ -z "$DEVICE" ] || [ "$CONFIRMATION" != "--confirm-wipe" ]; then
  echo "Usage: $0 /dev/<device> --confirm-wipe" >&2
  exit 2
fi

if [ ! -b "$DEVICE" ]; then
  echo "Refusing to format a path that is not a block device: $DEVICE" >&2
  exit 1
fi

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

if [ -e "/dev/disk/by-label/$MOUNT_LABEL" ]; then
  echo "Refusing to create a duplicate filesystem label: $MOUNT_LABEL" >&2
  exit 1
fi

if [ -d "$MOUNT_POINT" ] && [ -n "$(find "$MOUNT_POINT" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
  echo "Refusing to hide a non-empty containerd directory at $MOUNT_POINT" >&2
  exit 1
fi

sudo wipefs --all "$DEVICE"
sudo mkfs.ext4 -F -L "$MOUNT_LABEL" "$DEVICE"
sudo udevadm settle
sudo mkdir -p "$MOUNT_POINT"
sudo mount "/dev/disk/by-label/$MOUNT_LABEL" "$MOUNT_POINT"

mounted_source="$(findmnt --noheadings --output SOURCE --target "$MOUNT_POINT")"
resolved_device="$(readlink -f "$DEVICE")"
resolved_source="$(readlink -f "$mounted_source")"
if [ "$resolved_source" != "$resolved_device" ]; then
  echo "Unexpected device mounted at $MOUNT_POINT: $mounted_source" >&2
  exit 1
fi

echo "Prepared $DEVICE as $MOUNT_LABEL and mounted it at $MOUNT_POINT"
echo "Run make switch to install the persistent systemd mount dependency"
