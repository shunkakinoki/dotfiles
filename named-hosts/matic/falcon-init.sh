#!/usr/bin/env bash
# CrowdStrike Falcon sensor init script.
# @e2fsprogs@, @rsync@, @falcon@ are substituted by pkgs.replaceVars.
set -euo pipefail

# Remove immutable attributes set by CrowdStrike (security feature)
if [ -d /opt/CrowdStrike ]; then
  @e2fsprogs@/bin/chattr -i -R /opt/CrowdStrike 2>/dev/null || true
fi

install -d -m 0770 /opt/CrowdStrike

# Update binaries from the nix store, but preserve runtime state files.
# falconstore contains the Agent ID (AID) — if lost, the sensor re-registers
# as a new host and consumes another license seat.
@rsync@/bin/rsync -a --delete \
  --exclude=falconstore \
  --exclude=falconstore.bak \
  --exclude=CsConfig \
  "@falcon@/opt/CrowdStrike/" /opt/CrowdStrike/

chown -R root:root /opt/CrowdStrike

# load CID from /etc/falcon-sensor.env (root-only)
# shellcheck source=/dev/null
. /etc/falcon-sensor.env

# set CID via falconctl inside FHS env
@falcon@/bin/fs-bash -c "/opt/CrowdStrike/falconctl -s -f --cid=\"$FALCON_CID\""

# sanity print
@falcon@/bin/fs-bash -c "/opt/CrowdStrike/falconctl -g --cid"
