#!/usr/bin/env bash
# Neovim Test Runner
# Runs plenary-based tests for the Neovim configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_DIR="$SCRIPT_DIR"
PLENARY_DIR="${PLENARY_DIR:-/tmp/plenary.nvim}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running Neovim tests...${NC}"

# Check if nvim is available
if ! command -v nvim &>/dev/null; then
  echo -e "${RED}Error: Neovim is not installed or not in PATH${NC}"
  exit 1
fi

# Ensure plenary.nvim is available
if [ ! -d "$PLENARY_DIR" ]; then
  echo -e "${YELLOW}Cloning plenary.nvim to $PLENARY_DIR...${NC}"
  git clone --depth 1 https://github.com/nvim-lua/plenary.nvim "$PLENARY_DIR"
fi

# Export plenary directory for minimal_init.lua
export PLENARY_DIR

# Build telescope-fzf-native if libfzf.so is missing
PACK_DIR="$HOME/.local/share/nvim/site/pack"
for d in "$PACK_DIR"/*/opt/telescope-fzf-native.nvim "$PACK_DIR"/*/start/telescope-fzf-native.nvim; do
  if [ -d "$d" ] && [ ! -f "$d/build/libfzf.so" ]; then
    echo -e "${YELLOW}Building telescope-fzf-native.nvim...${NC}"
    make -C "$d" clean all
  fi
done

# Change to the nvim config directory
cd "$NVIM_DIR"

# Run tests
echo -e "${YELLOW}Executing tests...${NC}"
nvim --headless \
  -u tests/minimal_init.lua \
  -c "lua require('plenary.test_harness').test_directory('tests/', { minimal_init = 'tests/minimal_init.lua', sequential = true })"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
else
  echo -e "${RED}Tests failed with exit code: $EXIT_CODE${NC}"
fi

exit $EXIT_CODE
