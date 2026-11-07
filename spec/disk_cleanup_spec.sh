#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'disk-cleanup/cleanup.sh'
SCRIPT="$PWD/home-manager/services/disk-cleanup/cleanup.sh"

setup() {
  mock_bin_setup docker pgrep df
  CLEANUP_ROOT="$(mktemp -d)"
  export HOME="$CLEANUP_ROOT/home"
  unset npm_config_cache BUN_INSTALL_CACHE_DIR
  mkdir -p "$HOME/.npm/_npx/stale" "$HOME/.npm/_npx/fresh" "$HOME/.bun/install/cache/stale@1.0.0"
  touch -t 202001010000 "$HOME/.npm/_npx/stale" "$HOME/.bun/install/cache/stale@1.0.0"
  cat >"$MOCK_BIN/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
}

cleanup() {
  mock_bin_cleanup
  rm -rf "$CLEANUP_ROOT"
}

Before 'setup'
After 'cleanup'

run_cleanup() {
  bash "$SCRIPT" >/dev/null
  ls "$HOME/.npm/_npx" "$HOME/.bun/install/cache"
  cat "$MOCK_LOG"
}

It 'removes stale cache entries, keeps fresh ones, and prunes only unused Docker state'
When call run_cleanup
The status should be success
The output should include 'fresh'
The output should not include 'stale'
The output should include 'docker builder prune --force --filter until=24h'
The output should include 'docker image prune --force'
The output should include 'docker container prune --force --filter until=24h'
The output should not include 'volume'
The output should not include 'prune --all'
End

keep_in_use() {
  cat >"$MOCK_BIN/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  bash "$SCRIPT" >/dev/null
  ls "$HOME/.npm/_npx"
}

seed_agent_data() {
  local data="$HOME/.local/share" old=202001010000
  mkdir -p "$data/opencode" "$data/atuin.bak-1" "$data/atuin" \
    "$HOME/.codex/sessions/2020/01" "$HOME/.codex/sessions/2026/11" "$TMPDIR/opencode/stale"
  touch "$data/opencode/opencode-v2.db" "$data/opencode/opencode-pass-new.db" \
    "$HOME/.codex/sessions/2026/11/new.jsonl"
  touch -t "$old" "$data/opencode/opencode-stable.db" "$data/opencode/opencode-stable.db-wal" \
    "$data/opencode/opencode-pass-old.db" "$data/atuin.bak-1" "$data/atuin" \
    "$HOME/.codex/sessions/2020/01/old.jsonl" "$TMPDIR/opencode/stale"
  bash "$SCRIPT" >/dev/null
  find "$HOME/.local/share" "$HOME/.codex" "$TMPDIR" -mindepth 1 | sort
}

It 'prunes stale agent data and keeps live data'
export TMPDIR="$CLEANUP_ROOT/tmp"
unset XDG_DATA_HOME
When call seed_agent_data
The status should be success
The output should include 'opencode-v2.db'
The output should include 'opencode-pass-new.db'
The output should include 'new.jsonl'
The output should include "$HOME/.local/share/atuin"
The output should not include 'opencode-stable'
The output should not include 'opencode-pass-old'
The output should not include 'old.jsonl'
The output should not include 'sessions/2020'
The output should not include 'atuin.bak'
The output should not include 'stale'
End

It 'keeps an npx cache entry that a running process references'
When call keep_in_use
The status should be success
The output should include 'stale'
End
End
