#!/usr/bin/env bash
# Shared agent guardrail for pushes to protected default branches.
# This is an early warning only; remote rulesets and restricted credentials are
# the authoritative enforcement boundary.

# GUI-launched agents can inherit a minimal PATH on macOS.
export PATH="$HOME/.cargo/bin:/etc/profiles/per-user/shunkakinoki/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:${PATH:-}"

set -euo pipefail

ALLOWED_REPOS=(
  "shunkakinoki/wiki"
  "shunkakinoki/gthq"
)

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool.input.command // .tool_input.command // .toolArgs.command // .toolInput.command // .command // empty' 2>/dev/null)
[[ -z $command ]] && exit 0

repo=$(git remote get-url origin 2>/dev/null | sed -E 's#.*[:/]([^/]+/[^/]+)$#\1#; s#\.git$##' || true)
for allowed in "${ALLOWED_REPOS[@]}"; do
  [[ $repo == "$allowed" ]] && exit 0
done

protected_branches=(main master)
while IFS= read -r remote; do
  [[ -z $remote ]] && continue
  default_ref=$(git symbolic-ref --quiet --short "refs/remotes/$remote/HEAD" 2>/dev/null || true)
  [[ -z $default_ref ]] && continue
  default_branch=${default_ref#"$remote"/}
  protected_branches+=("$default_branch")
done < <(git remote 2>/dev/null || true)

is_protected_branch() {
  local candidate="$1"
  candidate=${candidate#+}
  candidate=${candidate#refs/heads/}
  candidate=${candidate#heads/}
  candidate=${candidate%\'}
  candidate=${candidate#\'}
  candidate=${candidate%\"}
  candidate=${candidate#\"}

  local protected
  for protected in "${protected_branches[@]}"; do
    [[ -n $protected && $candidate == "$protected" ]] && return 0
  done
  return 1
}

current_branch() {
  git symbolic-ref --quiet --short HEAD 2>/dev/null || true
}

block_push() {
  local destination="$1"
  printf "BLOCKED by block-git-push.sh: Push to protected branch '%s' in '%s'. Use a feature branch + PR.\n" \
    "$destination" "${repo:-unknown repository}" >&2
  exit 2
}

check_destination() {
  local destination="$1"
  local possible_branch=""

  if [[ $destination == refs/remotes/*/* ]]; then
    possible_branch=${destination#refs/remotes/}
    possible_branch=${possible_branch#*/}
  elif [[ $destination == refs/heads/* ]]; then
    possible_branch=${destination#refs/heads/}
  elif [[ $destination == heads/* ]]; then
    possible_branch=${destination#heads/}
  elif [[ $destination == */* ]] && git remote 2>/dev/null | grep -Fxq "${destination%%/*}"; then
    possible_branch=${destination#*/}
  fi

  if [[ -n $possible_branch ]] && is_protected_branch "$possible_branch"; then
    block_push "$possible_branch"
  fi
  if is_protected_branch "$destination"; then
    block_push "$destination"
  fi
}

check_current_destination() {
  local branch
  branch=$(current_branch)
  [[ -z $branch ]] && return 0

  local push_ref
  if push_ref=$(git rev-parse --abbrev-ref --symbolic-full-name '@{push}' 2>/dev/null) &&
    [[ -n $push_ref && $push_ref != '@{push}' ]]; then
    check_destination "$push_ref"
    return 0
  fi

  local push_default merge_ref
  push_default=$(git config --get push.default 2>/dev/null || printf '%s' simple)
  if [[ $push_default == upstream ]]; then
    merge_ref=$(git config --get "branch.$branch.merge" 2>/dev/null || true)
    if [[ -n $merge_ref ]]; then
      check_destination "$merge_ref"
      return 0
    fi
  fi

  check_destination "$branch"
}

check_refspec() {
  local refspec="$1"
  local delete_mode="$2"
  refspec=${refspec#+}
  refspec=${refspec%\'}
  refspec=${refspec#\'}
  refspec=${refspec%\"}
  refspec=${refspec#\"}

  if [[ $delete_mode == true ]]; then
    check_destination "$refspec"
    return 0
  fi

  case "$refspec" in
  HEAD | @ | '@{push}' | '@{upstream}')
    check_current_destination
    return 0
    ;;
  esac

  if [[ $refspec == *:* ]]; then
    check_destination "${refspec#*:}"
    return 0
  fi

  check_destination "$refspec"
}

implicit_remote() {
  local branch
  branch=$(current_branch)
  if [[ -n $branch ]]; then
    local configured
    configured=$(git config --get "branch.$branch.pushRemote" 2>/dev/null || true)
    [[ -n $configured ]] && printf '%s\n' "$configured" && return 0

    configured=$(git config --get remote.pushDefault 2>/dev/null || true)
    [[ -n $configured ]] && printf '%s\n' "$configured" && return 0

    configured=$(git config --get "branch.$branch.remote" 2>/dev/null || true)
    [[ -n $configured && $configured != . ]] && printf '%s\n' "$configured" && return 0
  fi

  if git remote get-url origin >/dev/null 2>&1; then
    printf '%s\n' origin
  fi
}

check_implicit_push() {
  local remote="$1"
  [[ -z $remote ]] && remote=$(implicit_remote)

  if [[ -n $remote ]]; then
    local configured_refspecs
    configured_refspecs=$(git config --get-all "remote.$remote.push" 2>/dev/null || true)
    if [[ -n $configured_refspecs ]]; then
      while IFS= read -r refspec; do
        [[ -n $refspec ]] && check_refspec "$refspec" false
      done <<<"$configured_refspecs"
      return 0
    fi
  fi

  local push_default
  push_default=$(git config --get push.default 2>/dev/null || printf '%s' simple)
  case "$push_default" in
  nothing)
    return 0
    ;;
  matching)
    local protected
    for protected in "${protected_branches[@]}"; do
      if git show-ref --verify --quiet "refs/heads/$protected"; then
        block_push "$protected"
      fi
    done
    ;;
  *)
    check_current_destination
    ;;
  esac
}

analyze_push_words() {
  local start_index="$1"
  local remote=""
  local delete_mode=false
  local saw_refspec=false
  local skip_next=false
  local index token

  for ((index = start_index; index < ${#words[@]}; index++)); do
    token=${words[index]}
    token=${token%;}
    token=${token%\}}
    token=${token#\{}

    if [[ $skip_next == true ]]; then
      skip_next=false
      continue
    fi

    case "$token" in
    --all | --mirror)
      local protected
      for protected in "${protected_branches[@]}"; do
        if git show-ref --verify --quiet "refs/heads/$protected"; then
          block_push "$protected"
        fi
      done
      block_push "default branch"
      ;;
    --delete | -d)
      delete_mode=true
      continue
      ;;
    --receive-pack | --exec | --repo | --push-option | -o)
      skip_next=true
      continue
      ;;
    --receive-pack=* | --exec=* | --repo=* | --push-option=* | -o*)
      continue
      ;;
    --*)
      continue
      ;;
    -*)
      continue
      ;;
    esac

    if [[ -z $remote ]]; then
      remote=$token
      continue
    fi

    saw_refspec=true
    check_refspec "$token" "$delete_mode"
  done

  if [[ $saw_refspec == false ]]; then
    check_implicit_push "$remote"
  fi
}

inspect_segment() {
  local segment="$1"
  local depth="$2"
  ((depth > 8)) && return 0

  read -r -a words <<<"$segment"
  local index git_index=-1 subcommand_index=-1 token
  for ((index = 0; index < ${#words[@]}; index++)); do
    token=${words[index]}
    token=${token%\}}
    token=${token#\{}
    if [[ $token == git || $token == */git ]]; then
      git_index=$index
      break
    fi
  done
  ((git_index < 0)) && return 0

  index=$((git_index + 1))
  while ((index < ${#words[@]})); do
    token=${words[index]}
    case "$token" in
    -C | --git-dir | --work-tree | --namespace)
      index=$((index + 2))
      continue
      ;;
    -C* | --git-dir=* | --work-tree=* | --namespace=* | --no-pager | --paginate | --literal-pathspecs | --no-literal-pathspecs | --glob-pathspecs | --noglob-pathspecs | --icase-pathspecs)
      index=$((index + 1))
      continue
      ;;
    -*)
      index=$((index + 1))
      continue
      ;;
    *)
      subcommand_index=$index
      break
      ;;
    esac
  done
  ((subcommand_index < 0)) && return 0

  local subcommand=${words[subcommand_index]}
  subcommand=${subcommand%;}
  if [[ $subcommand == push ]]; then
    analyze_push_words "$((subcommand_index + 1))"
    return 0
  fi

  local alias_value
  alias_value=$(git config --get "alias.$subcommand" 2>/dev/null || true)
  [[ -z $alias_value ]] && return 0

  local remainder=""
  for ((index = subcommand_index + 1; index < ${#words[@]}; index++)); do
    remainder+=" ${words[index]}"
  done

  if [[ $alias_value == !* ]]; then
    local alias_body=${alias_value#!}
    if printf '%s\n' "$alias_body" | grep -Eq 'git[[:space:]]+push.*(current-branch|branch[[:space:]]+--show-current|symbolic-ref[^)]*HEAD|rev-parse[^)]*HEAD)'; then
      local branch
      branch=$(current_branch)
      [[ -n $branch ]] && check_destination "$branch"
    fi
    inspect_command "$alias_body$remainder" "$((depth + 1))"
  else
    inspect_command "git $alias_value$remainder" "$((depth + 1))"
  fi
}

inspect_command() {
  local candidate="$1"
  local depth="${2:-0}"
  local segment
  while IFS= read -r segment; do
    [[ -z $segment ]] && continue
    inspect_segment "$segment" "$depth"
  done < <(printf '%s\n' "$candidate" | tr ';&|' '\n')
}

inspect_command "$command" 0
exit 0
