#!/usr/bin/env bash
# Feed agent-hook events to the RoboRev daemon running on this host.
# Start the full PR panel independently so the normal quick CI comment remains
# fast while the complete panel produces a second comment for the same PR.
# shellcheck disable=SC2016
set -euo pipefail

ROBOREV_BIN="${ROBOREV_BIN:-${HOME}/.local/bin/roborev}"
GH_BIN="${GH_BIN:-gh}"
GIT_BIN="${GIT_BIN:-git}"
JQ_BIN="${JQ_BIN:-jq}"
SERVER_ADDR="${ROBOREV_SERVER_ADDR:-127.0.0.1:7373}"
STATE_DIR="${ROBOREV_AGENT_FULL_REVIEW_STATE_DIR:-${HOME}/.roborev/agent-full-reviews}"

run_full_pr_review() {
  local cwd="$1" repo_path repo_key config_file pr_json pr_number pr_state
  local base_oid head_oid current_head merge_base lock_dir review_output comment_body

  repo_path="$($GIT_BIN -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" || return 0
  repo_key="${repo_path//\//_}"
  config_file="${repo_path}/.roborev.toml"
  [ -f "$config_file" ] || return 0
  grep -Eq '^\[review\.panels\.full\][[:space:]]*$' "$config_file" || return 0
  pr_json="$(cd "$repo_path" && "$GH_BIN" pr view \
    --json number,state,baseRefOid,headRefOid 2>/dev/null)" || return 0
  pr_number="$(printf '%s' "$pr_json" | "$JQ_BIN" -r '.number // empty')"
  pr_state="$(printf '%s' "$pr_json" | "$JQ_BIN" -r '.state // empty')"
  base_oid="$(printf '%s' "$pr_json" | "$JQ_BIN" -r '.baseRefOid // empty')"
  head_oid="$(printf '%s' "$pr_json" | "$JQ_BIN" -r '.headRefOid // empty')"
  current_head="$($GIT_BIN -C "$repo_path" rev-parse HEAD)"
  [[ $pr_number =~ ^[0-9]+$ ]] || return 0
  [ "$pr_state" = "OPEN" ] && [ "$current_head" = "$head_oid" ] || return 0
  [[ $base_oid =~ ^[0-9a-fA-F]{40}$ && $head_oid =~ ^[0-9a-fA-F]{40}$ ]] || return 0
  merge_base="$($GIT_BIN -C "$repo_path" merge-base "$base_oid" "$head_oid" 2>/dev/null)" || return 0
  [[ $merge_base =~ ^[0-9a-fA-F]{40}$ ]] || return 0

  lock_dir="${STATE_DIR}/${repo_key}/${head_oid}.enqueued"
  mkdir -p "$(dirname "$lock_dir")"
  mkdir "$lock_dir" 2>/dev/null || return 0

  if ! review_output="$($ROBOREV_BIN --server "$SERVER_ADDR" review --wait --quiet \
    --repo "$repo_path" --sha "${merge_base}..${head_oid}" --panel full)"; then
    rmdir "$lock_dir"
    return 1
  fi

  pr_json="$(cd "$repo_path" && "$GH_BIN" pr view "$pr_number" \
    --json state,headRefOid 2>/dev/null)" || return 0
  [ "$(printf '%s' "$pr_json" | "$JQ_BIN" -r '.state // empty')" = "OPEN" ] || return 0
  [ "$(printf '%s' "$pr_json" | "$JQ_BIN" -r '.headRefOid // empty')" = "$head_oid" ] || return 0

  comment_body="$(printf '## RoboRev Full Panel (`%s`)\n\n%s' "${head_oid:0:12}" "$review_output")"
  if ! (cd "$repo_path" && "$GH_BIN" pr comment "$pr_number" --body "$comment_body") >/dev/null; then
    rmdir "$lock_dir"
    return 1
  fi
}

launch_full_pr_review() {
  local cwd="$1" log_file
  if [ "${ROBOREV_AGENT_HOOK_SYNC:-0}" = "1" ]; then
    run_full_pr_review "$cwd"
    return
  fi
  mkdir -p "$STATE_DIR"
  log_file="${STATE_DIR}/full-review.log"
  nohup "$0" --full-pr-review "$cwd" </dev/null >>"$log_file" 2>&1 &
}

if [ "${1:-}" = "--full-pr-review" ]; then
  run_full_pr_review "${2:-}"
  exit 0
fi

if [ ! -x "$ROBOREV_BIN" ]; then
  exit 0
fi

INPUT="$(cat)"
HOOK_OUTPUT="$(printf '%s' "$INPUT" | "$ROBOREV_BIN" --server "$SERVER_ADDR" agent-hook run)" || true

if command -v "$JQ_BIN" >/dev/null 2>&1; then
  EVENT_NAME="$(printf '%s' "$INPUT" | "$JQ_BIN" -r '.hook_event_name // .hookEventName // empty' 2>/dev/null || true)"
  CWD="$(printf '%s' "$INPUT" | "$JQ_BIN" -r '.cwd // empty' 2>/dev/null || true)"
  TOOL_COMMAND="$(printf '%s' "$INPUT" | "$JQ_BIN" -r '.tool_input.command // .tool_input.cmd // .toolInput.command // empty' 2>/dev/null || true)"
  if [ -n "$CWD" ]; then
    case "$EVENT_NAME:$TOOL_COMMAND" in
    Stop:* | PostToolUse:*git\ push* | PostToolUse:*gh\ pr\ create*)
      launch_full_pr_review "$CWD" || true
      ;;
    esac
  fi
fi

printf '%s\n' "$HOOK_OUTPUT"
