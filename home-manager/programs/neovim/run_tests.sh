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

# Change to the nvim config directory
cd "$NVIM_DIR"

# Run tests
echo -e "${YELLOW}Executing tests...${NC}"
nvim --headless \
  -u tests/minimal_init.lua \
  -c "lua require('plenary.test_harness').test_directory('tests/', { minimal_init = 'tests/minimal_init.lua', sequential = true })" 2>&1 | tee /tmp/nvim-test-output.txt

# Plenary exits with code 2 even on success, so check output for failures instead
if grep -q "Failed : \s*[1-9]" /tmp/nvim-test-output.txt || grep -q "Errors : \s*[1-9]" /tmp/nvim-test-output.txt; then
  echo -e "${RED}Tests failed!${NC}"
  exit 1
else
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
