#!/usr/bin/env bash
# Hydrate CCS provider settings and config from templates
# Substitutes __CLIPROXY_API_KEY__ placeholder with actual API key from .env
# shellcheck source=/dev/null
set -euo pipefail

DOTFILES_DIR="${HOME}/dotfiles"
CCS_DIR="${HOME}/.ccs"
TEMPLATE_DIR="${DOTFILES_DIR}/config/ccs"
ENV_FILE="${DOTFILES_DIR}/.env"

# Load environment variables
if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

# Check for required API key
if [ -z "${CLIPROXY_API_KEY:-}" ]; then
  echo "Warning: CLIPROXY_API_KEY not set in .env, skipping CCS hydration" >&2
  exit 0
fi

# Optional API keys (warn if not set but continue)
if [ -z "${ZAI_API_KEY:-}" ]; then
  echo "Warning: ZAI_API_KEY not set in .env, GLM provider may not work" >&2
fi

mkdir -p "$CCS_DIR"

# Hydrate config.yaml
CONFIG_TEMPLATE="${TEMPLATE_DIR}/config.template.yaml"
if [ -f "$CONFIG_TEMPLATE" ]; then
  @sed@ \
    -e "s|__CLIPROXY_API_KEY__|${CLIPROXY_API_KEY}|g" \
    -e "s|__ZAI_API_KEY__|${ZAI_API_KEY:-}|g" \
    "$CONFIG_TEMPLATE" >"${CCS_DIR}/config.yaml"
  echo "Hydrated CCS config.yaml" >&2
fi

# Process all provider settings templates
for template in "$TEMPLATE_DIR"/*.settings.template.json; do
  [ -f "$template" ] || continue

  # Extract provider name: foo.settings.template.json -> foo
  filename=$(basename "$template")
  provider="${filename%.settings.template.json}"
  output="${CCS_DIR}/${provider}.settings.json"

  # Substitute placeholders and write output
  @sed@ \
    -e "s|__CLIPROXY_API_KEY__|${CLIPROXY_API_KEY}|g" \
    -e "s|__ZAI_API_KEY__|${ZAI_API_KEY:-}|g" \
    "$template" >"$output"

  echo "Hydrated CCS ${provider}.settings.json" >&2
done

# Hydrate accounts.json only if it doesn't exist (preserves runtime state like lastUsedAt)
ACCOUNTS_TEMPLATE="${TEMPLATE_DIR}/accounts.template.json"
ACCOUNTS_OUTPUT="${CCS_DIR}/cliproxy/accounts.json"
if [ -f "$ACCOUNTS_TEMPLATE" ] && [ ! -f "$ACCOUNTS_OUTPUT" ]; then
  mkdir -p "${CCS_DIR}/cliproxy"
  cp "$ACCOUNTS_TEMPLATE" "$ACCOUNTS_OUTPUT"
  echo "Hydrated CCS accounts.json (initial)" >&2
fi
