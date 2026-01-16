#!/usr/bin/env bash

set -euo pipefail

CLAWDBOT_DIR="$HOME/.config/clawdbot"
CLIPROXY_AUTH_DIR="$HOME/.cli-proxy-api/objectstore/auths"
DOTFILES_ENV="$HOME/dotfiles/.env"

mkdir -p "$CLAWDBOT_DIR"
chmod 700 "$CLAWDBOT_DIR"

# Extract secrets from .env
if [[ -f $DOTFILES_ENV ]]; then
  # Telegram token (Linux gateway only)
  @grep@ -E "^CLAWDBOT_TELEGRAM_TOKEN=" "$DOTFILES_ENV" 2>/dev/null | @cut@ -d= -f2- | @tr@ -d '"' >"$CLAWDBOT_DIR/telegram-token" || true
  
  # Gateway token (for remote mode clients / nodes)
  @grep@ -E "^CLAWDBOT_GATEWAY_TOKEN=" "$DOTFILES_ENV" 2>/dev/null | @cut@ -d= -f2- | @tr@ -d '"' >"$CLAWDBOT_DIR/gateway-token" || true
fi

# Read Claude OAuth access_token from cliproxyapi's synced auth (primary source)
CLAUDE_AUTH_FILE=$(@find@ "$CLIPROXY_AUTH_DIR" -name "claude-*.json" 2>/dev/null | @head@ -1)
if [[ -n $CLAUDE_AUTH_FILE ]] && [[ -f $CLAUDE_AUTH_FILE ]]; then
  @jq@ -r '.access_token // empty' "$CLAUDE_AUTH_FILE" >"$CLAWDBOT_DIR/anthropic-key" 2>/dev/null || true
  if [[ -s "$CLAWDBOT_DIR/anthropic-key" ]]; then
    echo "Extracted Claude OAuth from cliproxyapi auth" >&2
  fi
fi

# Fallback: if no cliproxyapi auth, try .env
if [[ ! -s "$CLAWDBOT_DIR/anthropic-key" ]] && [[ -f $DOTFILES_ENV ]]; then
  @grep@ -E "^CLAWDBOT_ANTHROPIC_KEY=" "$DOTFILES_ENV" 2>/dev/null | @cut@ -d= -f2- | @tr@ -d '"' >"$CLAWDBOT_DIR/anthropic-key" || true
fi

# Set secure permissions
chmod 600 "$CLAWDBOT_DIR"/* 2>/dev/null || true
