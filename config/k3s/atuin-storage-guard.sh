#!/usr/bin/env bash
set -euo pipefail

# A bind mount on root is still a mountpoint. Require the intended backing
# filesystem and directory before the daemon can write persistent history.
actual="$(findmnt --noheadings --raw --mountpoint /home/ubuntu/.local/share/atuin --output UUID,FSROOT)"
test "$actual" = "90f29a7b-38ff-460b-b534-92a02f1412ec /host-state/atuin-ubuntu"
