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

It 'keeps an npx cache entry that a running process references'
When call keep_in_use
The status should be success
The output should include 'stale'
End
End
