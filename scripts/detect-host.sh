#!/usr/bin/env bash
# Resolve the named host configuration for the current machine.
#
# Prints the host name on stdout, or nothing when the machine does not map to
# a named host. Reads its inputs from the environment so callers (and specs)
# can drive detection without touching the real machine:
#
#   OS, ARCH                          uname-derived platform
#   DMI_SYS_VENDOR, DMI_PRODUCT_NAME  /sys/class/dmi/id values on Linux
#   RUNPOD_POD_ID                     set inside RunPod containers

set -euo pipefail

OS="${OS:-}"
ARCH="${ARCH:-}"
DMI_SYS_VENDOR="${DMI_SYS_VENDOR:-}"
DMI_PRODUCT_NAME="${DMI_PRODUCT_NAME:-}"
RUNPOD_POD_ID="${RUNPOD_POD_ID:-}"

detect_darwin_host() {
  if [ "$(whoami 2>/dev/null || true)" != "shunkakinoki" ] || [ "$ARCH" != "arm64" ]; then
    return 0
  fi

  local computer_name
  computer_name="$(scutil --get ComputerName 2>/dev/null || true)"
  if echo "$computer_name" | grep -q "Shun's MacBook M4"; then
    echo "galactica"
  fi
  return 0
}

detect_linux_host() {
  if [ -n "$RUNPOD_POD_ID" ]; then
    echo "pod"
    return 0
  fi

  local hostname
  hostname="$(hostname 2>/dev/null || true)"
  case "$hostname" in
  kyber | matic)
    echo "$hostname"
    return 0
    ;;
  esac

  # Framework 13 (AMD Ryzen AI 300) ships with a generic hostname, so fall back
  # to the DMI identity burned into the board.
  if [ "$DMI_SYS_VENDOR" = "Framework" ] &&
    echo "$DMI_PRODUCT_NAME" | grep -q "Laptop 13.*AMD Ryzen AI 300"; then
    echo "matic"
  fi
  return 0
}

case "$OS" in
Darwin) detect_darwin_host ;;
Linux) detect_linux_host ;;
esac
