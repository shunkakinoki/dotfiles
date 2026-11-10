#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'disk-cleanup/cleanup.sh'
SCRIPT="$PWD/home-manager/services/disk-cleanup/cleanup.sh"

setup() {
  mock_bin_setup docker pgrep df
  CLEANUP_ROOT="$(mktemp -d)"
  export HOME="$CLEANUP_ROOT/home"
  export TMPDIR="$CLEANUP_ROOT/tmp" DISK_CLEANUP_VAR_TMP="$CLEANUP_ROOT/var"
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
The output should include 'docker image prune --all --force --filter until=168h'
The output should include 'docker container prune --force --filter until=24h'
The output should not include 'volume'
End

seed_retention_windows() {
  mkdir -p "$TMPDIR/queue-head-idle"
  python3 - "$HOME/.bun/install/cache/stale@1.0.0" "$TMPDIR/queue-head-idle" <<'PY'
import os
import sys
import time

for path, hours in zip(sys.argv[1:], [26, 2]):
    stamp = time.time() - hours * 3600
    os.utime(path, (stamp, stamp))
PY
  bash "$SCRIPT" >/dev/null
  [ ! -e "$HOME/.bun/install/cache/stale@1.0.0" ] && [ ! -e "$TMPDIR/queue-head-idle" ]
}

It 'reclaims caches after one day and idle scratch trees after one hour'
When call seed_retention_windows
The status should be success
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

It 'preserves agent history regardless of age and prunes stale scratch data'
unset XDG_DATA_HOME
When call seed_agent_data
The status should be success
The output should include 'opencode-v2.db'
The output should include 'opencode-pass-new.db'
The output should include 'new.jsonl'
The output should include "$HOME/.local/share/atuin"
The output should include 'opencode-stable'
The output should include 'opencode-pass-old'
The output should include 'old.jsonl'
The output should include 'sessions/2020'
The output should include 'atuin.bak'
The output should not include 'stale'
End

seed_scratch() {
  local tmp="$TMPDIR" var="$DISK_CLEANUP_VAR_TMP" old=202001010000
  mkdir -p "$tmp/stack-merge-tooling/olddir" "$tmp/stack-merge-tooling/busy" \
    "$var/ci-ship-reference-old" "$var/merged-tree-old" "$var/merged-tree-busy" "$var/unrelated-old"
  touch "$tmp/stack-merge-tooling/busy/live" "$var/merged-tree-busy/live" "$tmp/stack-merge-tooling/orphan.ready"
  touch -t "$old" "$tmp/stack-merge-tooling/olddir" "$tmp/stack-merge-tooling/olddir.ready" \
    "$tmp/stack-merge-tooling/orphan.lock" "$tmp/stack-merge-tooling/busy" \
    "$tmp/stack-merge-tooling/busy.ready" "$var/ci-ship-reference-old" "$var/merged-tree-old" \
    "$var/merged-tree-busy" "$var/unrelated-old"
  bash "$SCRIPT" >/dev/null
  find "$tmp/stack-merge-tooling" "$var" -mindepth 1 -maxdepth 1 | sort
}

It 'prunes stale scratch trees and keeps busy ones and their markers'
When call seed_scratch
The status should be success
The output should include 'stack-merge-tooling/busy'
The output should include 'busy.ready'
The output should include 'merged-tree-busy'
The output should include 'unrelated-old'
The output should not include 'olddir'
The output should not include 'orphan.lock'
The output should not include 'orphan.ready'
The output should not include 'ci-ship-reference-old'
The output should not include 'merged-tree-old'
End

seed_worktrees() {
  local repo="$CLEANUP_ROOT/repo" trees="$HOME/$1"
  git init -q --bare "$CLEANUP_ROOT/origin.git"
  git init -q "$repo"
  git -C "$repo" -c commit.gpgSign=false -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  git -C "$repo" remote add origin "$CLEANUP_ROOT/origin.git"
  git -C "$repo" push -q origin HEAD:main
  git -C "$repo" fetch -q origin
  mkdir -p "$trees"
  git -C "$repo" worktree add -q --detach "$trees/pushed" origin/main
  git -C "$repo" worktree add -q --detach "$trees/untracked" origin/main
  git -C "$repo" worktree add -q --detach "$trees/unpushed" origin/main
  git -C "$repo" worktree add -q --detach "$trees/secret" origin/main
  git -C "$repo" worktree add -q --detach "$trees/ignored" origin/main
  touch "$trees/untracked/new.txt"
  mkdir -p "$trees/secret/app" "$trees/ignored/dist" "$trees/pushed/dist"
  printf '.env*\ndist/\n' >"$repo/.git/info/exclude"
  touch "$trees/secret/app/.env.local" "$trees/ignored/dist/out.js" "$trees/pushed/dist/out.js"
  git -C "$trees/unpushed" -c commit.gpgSign=false -c user.name=t -c user.email=t@t commit -q --allow-empty -m local
  find "$trees" -exec touch -h -t 202001010000 {} +
  bash "$SCRIPT" >/dev/null
  find "$trees" -mindepth 1 -maxdepth 1 -exec basename {} \; | LC_ALL=C sort | paste -sd " " -
  git -C "$repo" worktree list
}

It 'prunes idle pushed codex worktrees and keeps ones with local work'
When call seed_worktrees .codex/worktrees
The status should be success
The line 1 of output should equal 'secret unpushed untracked'
The output should not match pattern '*worktrees/pushed *'
End

It 'prunes idle pushed t3 worktrees and keeps ones with local work'
When call seed_worktrees .t3/worktrees/repo
The status should be success
The line 1 of output should equal 'secret unpushed untracked'
The output should not match pattern '*worktrees/repo/pushed *'
End

It 'keeps an npx cache entry that a running process references'
When call keep_in_use
The status should be success
The output should include 'stale'
End

macos_cwd() {
  printf '#!/usr/bin/env bash\nprintf "Darwin\\n"\n' >"$MOCK_BIN/uname"
  cat >"$MOCK_BIN/lsof" <<'EOF'
#!/usr/bin/env bash
printf 'p123\nn%s/.npm/_npx/stale/child\n' "$HOME"
EOF
  chmod +x "$MOCK_BIN/uname" "$MOCK_BIN/lsof"
  bash "$SCRIPT" >/dev/null
  ls "$HOME/.npm/_npx" "$HOME/.bun/install/cache"
}

It 'keeps a cache used as a process cwd on macOS while removing idle caches'
When call macos_cwd
The status should be success
The output should include 'stale'
The output should not include 'stale@1.0.0'
End

macos_unknown_cwd() {
  printf '#!/usr/bin/env bash\nprintf "Darwin\\n"\n' >"$MOCK_BIN/uname"
  printf '#!/usr/bin/env bash\nexit 1\n' >"$MOCK_BIN/lsof"
  chmod +x "$MOCK_BIN/uname" "$MOCK_BIN/lsof"
  bash "$SCRIPT" >/dev/null
  result=$?
  ls "$HOME/.npm/_npx" "$HOME/.bun/install/cache"
  return "$result"
}

It 'keeps caches when the macOS process cwd inventory is unavailable'
When call macos_unknown_cwd
The status should equal 1
The output should include 'stale@1.0.0'
End
End
