#!/usr/bin/env bash
# Extensible overlay upgrade script
# Usage: ./scripts/upgrade-overlays.sh <target>

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Common utilities ---

log_info() {
  echo -e "${GREEN}$1${NC}"
}

log_warn() {
  echo -e "${YELLOW}$1${NC}"
}

log_error() {
  echo -e "${RED}$1${NC}"
}

usage() {
  echo "Usage: $0 <target>"
  echo ""
  echo "Available commands:"
  echo "  all        - Run all overlay upgrades (none configured yet)"
  echo ""
  echo "Examples:"
  echo "  $0 all"
}

main() {
  local target="${1:-}"

  if [ -z "$target" ]; then
    usage
    exit 1
  fi

  case "$target" in
  all)
    log_warn "No overlay upgrades configured."
    ;;
  -h | --help)
    usage
    ;;
  *)
    log_error "Unknown command: $target"
    echo ""
    usage
    exit 1
    ;;
  esac
}

main "$@"
