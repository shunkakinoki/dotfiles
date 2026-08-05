#!/usr/bin/env bash
# Shared Codex/Claude/Cursor/Factory Droid agent guardrail for GitHub repository control-plane mutations.
# This is an early warning only; restricted credentials and server-side
# rulesets are the authoritative enforcement boundary.

# GUI-launched agents can inherit a minimal PATH on macOS.
export PATH="$HOME/.cargo/bin:/etc/profiles/per-user/shunkakinoki/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:${PATH:-}"

set -euo pipefail

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool.input.command // .tool_input.command // .toolArgs.command // .toolInput.command // .command // empty' 2>/dev/null)
[[ -z $command ]] && exit 0

block_settings() {
  local detail="$1"
  printf "BLOCKED by block-gh-settings.sh: %s Repository settings must be changed manually.\n" "$detail" >&2
  exit 2
}

is_control_plane_target() {
  local candidate="$1"
  local repo_prefix="(api/v3/)?repos/[^/[:space:]\"']+/[^/?[:space:]\"']+"
  local protected_suffix="(rulesets|branches/[^/?[:space:]\"']+/protection|collaborators|teams|hooks|deploy_keys|keys|actions/(permissions|access|secrets|variables|cache/retention-limit|cache/storage-limit)|environments|pages|topics|vulnerability-alerts|automated-security-fixes|private-vulnerability-reporting|security-and-analysis|interaction-limits)"

  printf '%s\n' "$candidate" | grep -Eiq "${repo_prefix}([?[:space:]\"']|$)" && return 0
  printf '%s\n' "$candidate" | grep -Eiq "${repo_prefix}/${protected_suffix}([/?[:space:]\"']|$)"
}

explicit_method() {
  local candidate="$1"
  local method
  method=$(printf '%s\n' "$candidate" | sed -nE 's/.*(^|[[:space:]])(-X|--method)(=|[[:space:]]+)(GET|POST|PATCH|PUT|DELETE)([[:space:]]|$).*/\4/ip' | tail -1)
  if [[ -z $method ]]; then
    method=$(printf '%s\n' "$candidate" | sed -nE 's/.*(^|[[:space:]])-X(GET|POST|PATCH|PUT|DELETE)([[:space:]]|$).*/\2/ip' | tail -1)
  fi
  printf '%s' "${method^^}"
}

has_implicit_body() {
  local candidate="$1"
  printf '%s\n' "$candidate" | grep -Eiq '(^|[[:space:]])(-f|-F|--field|--raw-field|--input)(=|[[:space:]])'
}

if printf '%s\n' "$command" | grep -Eiq '(^|[;&|[:space:]])gh[[:space:]]+repo[[:space:]]+(delete|rename|archive|transfer|edit)([[:space:]]|$)'; then
  block_settings "A mutating 'gh repo' command was requested."
fi

if printf '%s\n' "$command" | grep -Eiq '(^|[;&|[:space:]])gh[[:space:]]+(secret|variable)[[:space:]]+(set|delete)([[:space:]]|$)'; then
  block_settings "A GitHub secret or variable mutation was requested."
fi

if printf '%s\n' "$command" | grep -Eiq '(^|[;&|[:space:]])gh[[:space:]]+repo[[:space:]]+deploy-key[[:space:]]+(add|delete)([[:space:]]|$)'; then
  block_settings "A repository deploy-key mutation was requested."
fi

if printf '%s\n' "$command" | grep -Eiq '(^|[;&|[:space:]])gh[[:space:]]+workflow[[:space:]]+(enable|disable)([[:space:]]|$)'; then
  block_settings "A workflow settings mutation was requested."
fi

if printf '%s\n' "$command" | grep -Eiq '(^|[;&|[:space:]])gh[[:space:]]+api[[:space:]]+([^;&|]*[[:space:]])?graphql([[:space:]]|$)'; then
  if printf '%s\n' "$command" | grep -Eiq '(^|[^[:alnum:]_])mutation([^[:alnum:]_]|$)' ||
    printf '%s\n' "$command" | grep -Eiq '(^|[[:space:]])--input(=|[[:space:]])'; then
    block_settings "A raw GraphQL mutation was requested."
  fi
fi

if printf '%s\n' "$command" | grep -Eiq '(^|[;&|[:space:]])gh[[:space:]]+api([[:space:]]|$)' && is_control_plane_target "$command"; then
  method=$(explicit_method "$command")
  if [[ -z $method ]] && has_implicit_body "$command"; then
    method=POST
  fi
  if [[ $method =~ ^(POST|PATCH|PUT|DELETE)$ ]]; then
    block_settings "A $method request to a repository control-plane endpoint was requested."
  fi
fi

if is_control_plane_target "$command"; then
  http_method=$(explicit_method "$command")

  if printf '%s\n' "$command" | grep -Eiq '(^|[;&|[:space:]])(http|https|xh)[[:space:]]+(POST|PATCH|PUT|DELETE)([[:space:]]|$)'; then
    http_method=$(printf '%s\n' "$command" | sed -nE 's/.*(^|[;&|[:space:]])(http|https|xh)[[:space:]]+(POST|PATCH|PUT|DELETE)([[:space:]]|$).*/\3/ip' | tail -1)
  fi

  if [[ -z $http_method ]]; then
    http_method=$(printf '%s\n' "$command" | sed -nE 's/.*(^|[[:space:]])--request(=|[[:space:]]+)(POST|PATCH|PUT|DELETE)([[:space:]]|$).*/\3/ip' | tail -1)
  fi

  if [[ -z $http_method ]] &&
    printf '%s\n' "$command" | grep -Eiq '(^|[;&|[:space:]])curl([[:space:]]|$)' &&
    printf '%s\n' "$command" | grep -Eiq '(^|[[:space:]])(--data[^[:space:]]*|-d|--form|-F|--json|--upload-file|-T)(=|[[:space:]])'; then
    http_method=POST
  fi

  if [[ -z $http_method ]] &&
    printf '%s\n' "$command" | grep -Eiq '(^|[;&|[:space:]])(http|https|xh)([[:space:]]|$)' &&
    printf '%s\n' "$command" | grep -Eq '(^|[[:space:]])[^-[:space:]=?:/][^[:space:]=?/]*(:=|=)[^[:space:]]+'; then
    http_method=POST
  fi

  if [[ -z $http_method ]] &&
    printf '%s\n' "$command" | grep -Eiq '(^|[;&|[:space:]])wget([[:space:]]|$)' &&
    printf '%s\n' "$command" | grep -Eiq '(^|[[:space:]])(--post-data|--post-file|--body-data)(=|[[:space:]])'; then
    http_method=POST
  fi

  http_method=${http_method^^}
  if [[ $http_method =~ ^(POST|PATCH|PUT|DELETE)$ ]]; then
    block_settings "A direct $http_method request to a repository control-plane endpoint was requested."
  fi
fi

exit 0
