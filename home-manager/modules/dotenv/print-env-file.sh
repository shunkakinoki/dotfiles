#!/usr/bin/env sh
# Single .env parser for every shell and for the GUI exporter: each consumer only
# applies the KEY=VALUE lines printed here, so the parsing rules cannot drift.
set -eu

env_file=""
for candidate in "${DOTFILES_ENV_FILE:-}" "$HOME/dotfiles/.env" "$HOME/.env"; do
  [ -n "$candidate" ] || continue
  if [ -f "$candidate" ]; then
    env_file="$candidate"
    break
  fi
done

[ -n "$env_file" ] || exit 0

# `|| [ -n "$line" ]` keeps a trailing line that has no newline.
while IFS= read -r line || [ -n "$line" ]; do
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"

  case "$line" in
  '' | '#'*) continue ;;
  export[[:space:]]*)
    line="${line#export}"
    line="${line#"${line%%[![:space:]]*}"}"
    ;;
  esac

  case "$line" in
  *=*) ;;
  *) continue ;;
  esac

  key="${line%%=*}"
  value="${line#*=}"

  key="${key%"${key##*[![:space:]]}"}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"

  case "$key" in
  '' | [0-9]* | *[!A-Za-z0-9_]*) continue ;;
  esac

  case "$value" in
  \"*\") value="${value%\"}" && value="${value#\"}" ;;
  \'*\') value="${value%\'}" && value="${value#\'}" ;;
  esac

  printf '%s=%s\n' "$key" "$value"
done <"$env_file"
