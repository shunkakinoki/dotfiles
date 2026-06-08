#!/usr/bin/env bash
# CrowdStrike Falcon sensor init script.
# @e2fsprogs@, @rsync@, @falcon@ are substituted by pkgs.replaceVars.
set -euo pipefail

# Remove immutable attributes set by CrowdStrike (security feature)
if [ -d /opt/CrowdStrike ]; then
  @e2fsprogs@/bin/chattr -i -R /opt/CrowdStrike 2>/dev/null || true
fi

install -d -m 0770 /opt/CrowdStrike

# CrowdStrike pushes OTA updates that write newer versioned binaries into
# /opt/CrowdStrike/. Only rsync the packaged binaries when the installed
# version is not newer than the package, otherwise the rsync clobbers the
# update and the running sensor can't find its helper binaries (ENOENT).
pkg_ver="@falcon@/opt/CrowdStrike/falconctl"
installed_ver=/opt/CrowdStrike/falconctl
need_sync=true

if [ -x "$installed_ver" ]; then
  pkg_build=$(readlink -f "$pkg_ver" | grep -oP '\d+$' || echo "0")
  inst_build=$(readlink -f "$installed_ver" | grep -oP '\d+$' || echo "0")
  if [ "$inst_build" -gt "$pkg_build" ] 2>/dev/null; then
    echo "falcon-init: installed build $inst_build is newer than packaged $pkg_build, skipping rsync"
    need_sync=false
  fi
fi

if [ "$need_sync" = true ]; then
  # Update binaries from the nix store, but preserve runtime state files.
  # falconstore contains the Agent ID (AID) - if lost, the sensor re-registers
  # as a new host and consumes another license seat.
  @rsync@/bin/rsync -a --delete \
    --exclude=falconstore \
    --exclude=falconstore.bak \
    --exclude=CsConfig \
    "@falcon@/opt/CrowdStrike/" /opt/CrowdStrike/
fi

chown -R root:root /opt/CrowdStrike

# load CID from /etc/falcon-sensor.env (root-only)
# shellcheck source=/dev/null
. /etc/falcon-sensor.env

# set CID via falconctl inside FHS env
@falcon@/bin/fs-bash -c "/opt/CrowdStrike/falconctl -s -f --cid=\"$FALCON_CID\""

# sanity print
@falcon@/bin/fs-bash -c "/opt/CrowdStrike/falconctl -g --cid"
