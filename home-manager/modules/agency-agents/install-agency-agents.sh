#!/usr/bin/env bash
#
# Clone/update msitarzewski/agency-agents and install the roster into local
# agentic tools via upstream scripts/install.sh (non-interactive).
#
# Soft-skips on boot, offline, missing git, or transient clone/install failures
# so home-manager activation does not hard-fail (mirrors uv/npm-globals).

set -euo pipefail

REPO_URL="https://github.com/msitarzewski/agency-agents.git"
REPO_DIR="${HOME}/.local/share/agency-agents"

# Primary tools: user-wide destinations under $HOME.
# OpenCode is installed separately with a curated --division set (see below).
PRIMARY_TOOLS="claude-code,codex,openclaw,cursor"

# OpenCode silently drops past ~119 agents (anomalyco/opencode#27988).
# engineering+product+security+testing+design stays under that cap.
OPENCODE_DIVISIONS="engineering,product,security,testing,design"

# Skip during boot on Linux (SYSTEMCTL_BIN set by nix activation)
if [ -n "${SYSTEMCTL_BIN:-}" ] && [ "$("$SYSTEMCTL_BIN" is-system-running 2>/dev/null)" = "starting" ]; then
  echo "System is booting, skipping agency-agents install"
  exit 0
fi

# Skip if offline (same probe as uv-globals / npm-globals)
if ! timeout 3 bash -c 'exec 3<>/dev/tcp/1.1.1.1/53' 2>/dev/null; then
  echo "Network unavailable, skipping agency-agents install"
  exit 0
fi

if ! command -v git &>/dev/null; then
  echo "git not found, skipping agency-agents install"
  exit 0
fi

sync_repo() {
  if [ ! -d "${REPO_DIR}/.git" ]; then
    echo "Cloning agency-agents into ${REPO_DIR}..."
    mkdir -p "$(dirname "$REPO_DIR")"
    if ! git clone --depth 1 "$REPO_URL" "$REPO_DIR"; then
      echo "Failed to clone agency-agents, skipping..."
      return 1
    fi
    return 0
  fi

  echo "Updating agency-agents in ${REPO_DIR}..."
  # Prefer ff-only pull; fall back to fetch + hard reset to origin/main so a
  # dirty/diverged checkout still converges on upstream without failing activation.
  if git -C "$REPO_DIR" pull --ff-only origin main 2>/dev/null; then
    return 0
  fi
  if git -C "$REPO_DIR" fetch origin main &&
    git -C "$REPO_DIR" reset --hard origin/main; then
    return 0
  fi
  echo "Failed to update agency-agents, skipping..."
  return 1
}

if ! sync_repo; then
  exit 0
fi

INSTALL_SH="${REPO_DIR}/scripts/install.sh"
if [ ! -x "$INSTALL_SH" ] && [ ! -f "$INSTALL_SH" ]; then
  echo "agency-agents install.sh missing at ${INSTALL_SH}, skipping..."
  exit 0
fi
chmod +x "$INSTALL_SH" 2>/dev/null || true

# Home-scoped destinations for tools that default to $PWD (project-local).
export CURSOR_RULES_DIR="${HOME}/.cursor/rules"
export OPENCODE_AGENTS_DIR="${HOME}/.config/opencode/agents"

# Ensure destination parents exist so installers do not fail on mkdir races.
mkdir -p \
  "${HOME}/.claude/agents" \
  "${HOME}/.codex/agents" \
  "${HOME}/.openclaw/agency-agents" \
  "${CURSOR_RULES_DIR}" \
  "${OPENCODE_AGENTS_DIR}"

cd "$REPO_DIR"

# Drop previously generated integration outputs (keep README.md). After a repo
# update, ensure_converted would otherwise skip convert when stale files remain.
for _tool in codex openclaw cursor opencode; do
  _dir="${REPO_DIR}/integrations/${_tool}"
  if [ -d "$_dir" ]; then
    find "$_dir" -type f ! -name 'README.md' -delete 2>/dev/null || true
  fi
done

echo "Installing agency-agents for tools: ${PRIMARY_TOOLS} (all divisions)..."
if ! ./scripts/install.sh --no-interactive --tool "$PRIMARY_TOOLS"; then
  echo "agency-agents primary install failed, continuing..."
fi

echo "Installing agency-agents for opencode (divisions: ${OPENCODE_DIVISIONS})..."
if ! ./scripts/install.sh --no-interactive --tool opencode --division "$OPENCODE_DIVISIONS"; then
  echo "agency-agents opencode install failed, continuing..."
fi

echo "agency-agents installation complete"
