#!/usr/bin/env bash
# Shared agent guardrail against rewriting the git commit identity.
# A repo-local user.name/user.email overrides the Home Manager identity for
# every worktree sharing that repository, so one agent's write misattributes
# all later commits on the host. Per-command `git -c user.name=...` and
# GIT_AUTHOR_*/GIT_COMMITTER_* stay available for throwaway repositories.

# GUI-launched agents can inherit a minimal PATH on macOS.
export PATH="$HOME/.cargo/bin:/etc/profiles/per-user/shunkakinoki/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:${PATH:-}"

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool.input.command // .tool_input.command // .toolArgs.command // .toolInput.command // .command // empty' 2>/dev/null)
[[ -z $command ]] && exit 0

strip_token() {
  local token="$1"
  token=${token#[\"\'\{\(]}
  token=${token%[\"\'\}\);]}
  printf '%s' "$token"
}

is_identity_key() {
  local key
  key=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  [[ $key == user.name || $key == user.email ]]
}

inspect_segment() {
  local segment="$1"
  local -a words
  read -r -a words <<<"$segment"

  local index git_index=-1 token
  for ((index = 0; index < ${#words[@]}; index++)); do
    token=$(strip_token "${words[index]}")
    if [[ $token == git || $token == */git ]]; then
      git_index=$index
      break
    fi
  done
  ((git_index < 0)) && return 0

  index=$((git_index + 1))
  while ((index < ${#words[@]})); do
    case "${words[index]}" in
    -C | -c | --git-dir | --work-tree | --namespace | --config-env)
      index=$((index + 2))
      ;;
    -*)
      index=$((index + 1))
      ;;
    *)
      break
      ;;
    esac
  done
  ((index >= ${#words[@]})) && return 0
  [[ $(strip_token "${words[index]}") == config ]] || return 0

  local key="" values=0 write=false
  for ((index = index + 1; index < ${#words[@]}; index++)); do
    token=$(strip_token "${words[index]}")
    case "$token" in
    set | unset | --unset | --unset-all | --replace-all | --add | --rename-section | --remove-section)
      write=true
      ;;
    get | list | --get | --get-all | --get-regexp | --get-urlmatch | -l | --list)
      return 0
      ;;
    -f | --file | --blob | --type | --default | --comment)
      index=$((index + 1))
      ;;
    -*) ;;
    *)
      if [[ -z $key ]]; then
        key=$token
      else
        values=$((values + 1))
      fi
      ;;
    esac
  done

  is_identity_key "$key" || [[ $key == user && $write == true ]] || return 0
  if [[ $write == true || $values -gt 0 ]]; then
    printf "BLOCKED by block-git-identity.sh: '%s' rewrites the git commit identity. Commit with the configured identity; use 'git -c user.name=... -c user.email=...' only inside a throwaway repository.\n" \
      "$segment" >&2
    exit 2
  fi
}

while IFS= read -r segment; do
  [[ -z $segment ]] && continue
  inspect_segment "$segment"
done < <(printf '%s\n' "$command" | tr ';&|' '\n')

exit 0
