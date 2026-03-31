#!/usr/bin/env bash
# Sync OAuth tokens from local credential stores into cliproxyapi auth dir.
#
# Sources:
#   - Claude Code: macOS Keychain (Claude Code-credentials / <username>)
#   - Codex CLI:   ~/.codex/auth.json
#
# On first run, macOS will prompt to allow keychain access — click "Always Allow".
# shellcheck source=/dev/null
set -euo pipefail

AUTH_DIR="${HOME}/.cli-proxy-api/objectstore/auths"
EMAIL="@email@"
KEYCHAIN_ACCOUNT="@keychain_account@"
JQ="@jq@"

SECURITY="${SECURITY:-/usr/bin/security}"

mkdir -p "$AUTH_DIR"

changed=0

# --- Claude Code (keychain) ---
sync_claude() {
  local raw
  raw=$("$SECURITY" find-generic-password \
    -s "Claude Code-credentials" \
    -a "$KEYCHAIN_ACCOUNT" \
    -w 2>/dev/null) || return 0

  if [ -z "$raw" ]; then
    echo "[$(date)] Claude: keychain entry empty, skipping" >&2
    return 0
  fi

  # Claude Code stores JSON: { claudeAiOauth: { accessToken, refreshToken, expiresAt (epoch ms), ... } }
  local access_token refresh_token expires_at
  access_token=$($JQ -r '.claudeAiOauth.accessToken // empty' <<<"$raw" 2>/dev/null) || true
  refresh_token=$($JQ -r '.claudeAiOauth.refreshToken // empty' <<<"$raw" 2>/dev/null) || true
  expires_at=$($JQ -r '.claudeAiOauth.expiresAt // empty' <<<"$raw" 2>/dev/null) || true

  # Convert epoch ms to ISO 8601
  if [ -n "$expires_at" ] && [ "$expires_at" != "null" ]; then
    expires_at=$(date -u -r "$((expires_at / 1000))" +%Y-%m-%dT%H:%M:%S+00:00 2>/dev/null) || expires_at=""
  fi

  if [ -z "$access_token" ]; then
    echo "[$(date)] Claude: no access_token in keychain data, skipping" >&2
    return 0
  fi

  local dest="$AUTH_DIR/claude-${EMAIL}.json"
  local new_json
  # shellcheck disable=SC2016
  # refresh_interval_seconds=999999999 disables cliproxyapi's built-in
  # auto-refresh for this auth entry. Without this, cliproxyapi refreshes
  # Claude tokens 4h before expiry, rotating the refresh_token. keychain-sync
  # then overwrites with the old (now-invalidated) refresh_token, breaking the
  # refresh chain. Let Claude Code handle its own token lifecycle instead.
  new_json=$($JQ -n \
    --arg at "$access_token" \
    --arg rt "${refresh_token:-}" \
    --arg email "$EMAIL" \
    --arg expired "${expires_at:-}" \
    --arg last_refresh "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)" \
    '{
      access_token: $at,
      disabled: false,
      email: $email,
      expired: $expired,
      id_token: "",
      last_refresh: $last_refresh,
      refresh_interval_seconds: 999999999,
      refresh_token: $rt,
      type: "claude"
    }')

  # Only write if token changed
  local existing_at=""
  if [ -f "$dest" ]; then
    existing_at=$($JQ -r '.access_token // empty' "$dest" 2>/dev/null) || true
  fi

  if [ "$access_token" != "$existing_at" ]; then
    local tmp
    tmp=$(mktemp "${AUTH_DIR}/.claude-sync.XXXXXX")
    printf '%s' "$new_json" >"$tmp" && mv "$tmp" "$dest" || rm -f "$tmp"
    echo "[$(date)] Claude: synced new token to $dest" >&2
    changed=1
  fi
}

# --- Codex CLI (file) ---
sync_codex() {
  local auth_file="${HOME}/.codex/auth.json"
  if [ ! -f "$auth_file" ]; then
    return 0
  fi

  local access_token refresh_token account_id
  access_token=$($JQ -r '.tokens.access_token // .OPENAI_API_KEY // empty' "$auth_file" 2>/dev/null) || true
  refresh_token=$($JQ -r '.tokens.refresh_token // empty' "$auth_file" 2>/dev/null) || true
  account_id=$($JQ -r '.account_id // empty' "$auth_file" 2>/dev/null) || true

  if [ -z "$access_token" ]; then
    echo "[$(date)] Codex: no token in auth file, skipping" >&2
    return 0
  fi

  local dest="$AUTH_DIR/codex-${EMAIL}.json"
  local last_refresh
  last_refresh=$($JQ -r '.last_refresh // empty' "$auth_file" 2>/dev/null) || true

  local new_json
  # shellcheck disable=SC2016
  new_json=$($JQ -n \
    --arg at "$access_token" \
    --arg rt "${refresh_token:-}" \
    --arg email "$EMAIL" \
    --arg account_id "${account_id:-}" \
    --arg last_refresh "${last_refresh:-$(date -u +%Y-%m-%dT%H:%M:%S+00:00)}" \
    '{
      access_token: $at,
      account_id: $account_id,
      disabled: false,
      email: $email,
      expired: "",
      id_token: "",
      last_refresh: $last_refresh,
      refresh_token: $rt,
      type: "codex"
    }')

  local existing_at=""
  if [ -f "$dest" ]; then
    existing_at=$($JQ -r '.access_token // empty' "$dest" 2>/dev/null) || true
  fi

  if [ "$access_token" != "$existing_at" ]; then
    local tmp
    tmp=$(mktemp "${AUTH_DIR}/.codex-sync.XXXXXX")
    printf '%s' "$new_json" >"$tmp" && mv "$tmp" "$dest" || rm -f "$tmp"
    echo "[$(date)] Codex: synced new token to $dest" >&2
    changed=1
  fi
}

sync_claude
sync_codex

if [ "$changed" -eq 1 ]; then
  echo "[$(date)] Auth files updated — backup watcher will push to S3" >&2
fi
