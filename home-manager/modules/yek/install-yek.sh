#!/usr/bin/env bash

set -euo pipefail

REPO_OWNER="bodo-run"
REPO_NAME="yek"
TARGET="@target@"
ASSET_NAME="yek-${TARGET}.tar.gz"
INSTALL_DIR="$HOME/.local/bin"

mkdir -p "$INSTALL_DIR"

echo "Fetching latest release info from GitHub..."
LATEST_URL=$(
  @curl@ -s "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest" |
    @grep@ "browser_download_url" |
    @grep@ "${ASSET_NAME}" |
    @cut@ -d '"' -f 4
)

if [ -z "${LATEST_URL}" ]; then
  echo "Failed to find a release asset named ${ASSET_NAME} in the latest release."
  exit 1
fi

echo "Downloading from: ${LATEST_URL}"
TEMP_DIR=$(@mktemp@ -d)
cd "$TEMP_DIR"
@curl@ -L -o "${ASSET_NAME}" "${LATEST_URL}"

echo "Extracting archive..."
@tar@ xzf "${ASSET_NAME}"

echo "Installing binary to ${INSTALL_DIR}..."
@install@ -Dm755 "yek-${TARGET}/yek" "${INSTALL_DIR}/yek"

echo "✅ yek installed successfully to ${INSTALL_DIR}/yek"
echo "Version: $("${INSTALL_DIR}/yek" --version)"

# Cleanup
rm -rf "$TEMP_DIR"
