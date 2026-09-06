#!/usr/bin/env bash
set -euo pipefail

# Use the shared shell injector on every server start, including after login.
# shellcheck source=/dev/null
. "${HOME}/.config/shell/load-env-file.sh"
_hm_load_env_file

exec "$1" server
