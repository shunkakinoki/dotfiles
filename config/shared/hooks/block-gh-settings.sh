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

mutating_method() {
  local method=${1^^}
  [[ $method =~ ^(POST|PATCH|PUT|DELETE)$ ]]
}

is_control_plane_endpoint() {
  local path="$1"
  if [[ $path == *://* ]]; then
    path=${path#*://}
    path=${path#*/}
  fi
  path=${path%%\?*}
  path=${path%%#*}
  path=${path#/}
  path=${path%/}

  local repo='(api/v3/)?repos/[^/]+/[^/]+'
  local protected='(rulesets|branches/[^/]+/protection|collaborators|teams|hooks|deploy_keys|keys|actions/(permissions|access|secrets|variables|cache/retention-limit|cache/storage-limit)|environments|pages|topics|vulnerability-alerts|automated-security-fixes|private-vulnerability-reporting|security-and-analysis|interaction-limits)'

  [[ $path =~ ^${repo}$ ]] && return 0
  [[ $path =~ ^${repo}/${protected}(/.*)?$ ]]
}

has_control_plane_argument() {
  local arg
  for arg in "$@"; do
    if is_control_plane_endpoint "$arg"; then
      return 0
    fi
  done
  return 1
}

# Root selection fields of a GraphQL mutation document, one per line. Argument
# values and nested selections sit at a deeper depth, so a repository field
# selected inside a pull request mutation never reads as a root field.
mutation_root_fields() {
  local rest=${1#*mutation}
  rest=${rest#*\{}

  local length=${#rest}
  local index=0
  local depth=0
  local name=''
  local char

  while ((index < length)); do
    char=${rest:index:1}
    index=$((index + 1))

    if [[ $char == '"' ]]; then
      while ((index < length)) && [[ ${rest:index:1} != '"' ]]; do
        if [[ ${rest:index:1} == "\\" ]]; then
          index=$((index + 1))
        fi
        index=$((index + 1))
      done
      index=$((index + 1))
      continue
    fi

    if [[ $char == [A-Za-z0-9_] ]]; then
      name+=$char
      continue
    fi

    if [[ -n $name ]]; then
      # A name followed by a colon is an alias, not the invoked field.
      if ((depth == 0)) && [[ $char != ':' ]]; then
        printf '%s\n' "$name"
      fi
      name=''
    fi

    case $char in
    '(' | '{' | '[') depth=$((depth + 1)) ;;
    ')' | '}' | ']')
      depth=$((depth - 1))
      if ((depth < 0)); then
        return 0
      fi
      ;;
    esac
  done

  if [[ -n $name ]] && ((depth == 0)); then
    printf '%s\n' "$name"
  fi
}

is_settings_mutation() {
  local name=${1,,}
  [[ $name =~ (repository|organization|enterprise|team|collaborator|branchprotection|ruleset|ipallowlist|environment|deploykey|webhook|interactionlimit|verifiabledomain|topics|pages|secret|variable|actionspermission|securityanalysis|vulnerabilityalert) ]]
}

check_graphql() {
  # A document read from a file, from stdin, or from a shell expansion cannot be
  # inspected, so it is treated as a settings mutation.
  if ((gql_opaque)) || [[ -z $gql_document || $gql_document == @* || $gql_document == '$'* ]]; then
    block_settings "A GraphQL document that could not be inspected was requested."
  fi

  local operation='(^|[^[:alnum:]_])mutation[[:space:]]*([A-Za-z_({]|$)'
  if [[ ! $gql_document =~ $operation ]]; then
    return 0
  fi

  local field
  while IFS= read -r field; do
    if is_settings_mutation "$field"; then
      block_settings "The GraphQL mutation '$field' changes repository or organization settings."
    fi
  done < <(mutation_root_fields "$gql_document")
}

gql_document=''
gql_opaque=0

record_gh_api_field() {
  if [[ $1 == query=* ]]; then
    gql_document=${1#query=}
  fi
}

check_gh_api() {
  while (($#)) && [[ $1 != api ]]; do
    shift
  done
  if (($# == 0)); then
    return 0
  fi
  shift

  local endpoint='' method='' body=0 arg
  gql_document=''
  gql_opaque=0

  while (($#)); do
    arg=$1
    case $arg in
    -X | --method)
      method=${2-}
      shift $(($# > 1 ? 2 : 1))
      ;;
    --method=*)
      method=${arg#--method=}
      shift
      ;;
    -X?*)
      method=${arg#-X}
      shift
      ;;
    -f | -F | --field | --raw-field)
      record_gh_api_field "${2-}"
      body=1
      shift $(($# > 1 ? 2 : 1))
      ;;
    --field=* | --raw-field=*)
      record_gh_api_field "${arg#*=}"
      body=1
      shift
      ;;
    -f?* | -F?*)
      record_gh_api_field "${arg:2}"
      body=1
      shift
      ;;
    --input)
      gql_opaque=1
      body=1
      shift $(($# > 1 ? 2 : 1))
      ;;
    --input=*)
      gql_opaque=1
      body=1
      shift
      ;;
    -H | --header | -q | --jq | -t | --template | --hostname | --cache | -p | --preview)
      shift $(($# > 1 ? 2 : 1))
      ;;
    -*)
      shift
      ;;
    *)
      if [[ -z $endpoint ]]; then
        endpoint=$arg
      fi
      shift
      ;;
    esac
  done

  if [[ $endpoint == graphql ]]; then
    check_graphql
    return 0
  fi

  if [[ -z $method ]] && ((body)); then
    method=POST
  fi

  if mutating_method "$method" && is_control_plane_endpoint "$endpoint"; then
    block_settings "A ${method^^} request to a repository control-plane endpoint was requested."
  fi
}

check_gh() {
  local -a words=()
  local arg
  for arg in "$@"; do
    if [[ $arg != -* ]]; then
      words+=("$arg")
    fi
  done

  case "${words[0]-} ${words[1]-}" in
  'repo delete' | 'repo rename' | 'repo archive' | 'repo transfer' | 'repo edit')
    block_settings "A mutating 'gh repo' command was requested."
    ;;
  'secret set' | 'secret delete' | 'variable set' | 'variable delete')
    block_settings "A GitHub secret or variable mutation was requested."
    ;;
  'workflow enable' | 'workflow disable')
    block_settings "A workflow settings mutation was requested."
    ;;
  esac

  case "${words[0]-} ${words[1]-} ${words[2]-}" in
  'repo deploy-key add' | 'repo deploy-key delete')
    block_settings "A repository deploy-key mutation was requested."
    ;;
  esac

  if [[ ${words[0]-} == api ]]; then
    check_gh_api "$@"
  fi
}

check_curl() {
  if ! has_control_plane_argument "$@"; then
    return 0
  fi

  local method='' body=0 arg previous=''
  for arg in "$@"; do
    if [[ $previous == -X || $previous == --request ]]; then
      method=$arg
    fi
    case $arg in
    --request=*) method=${arg#--request=} ;;
    -X?*) method=${arg#-X} ;;
    -d | -F | -T | --data | --data-* | --form | --json | --upload-file) body=1 ;;
    -d?* | --data=*) body=1 ;;
    esac
    previous=$arg
  done

  if [[ -z $method ]] && ((body)); then
    method=POST
  fi

  if mutating_method "$method"; then
    block_settings "A direct ${method^^} request to a repository control-plane endpoint was requested."
  fi
}

check_httpie() {
  if ! has_control_plane_argument "$@"; then
    return 0
  fi

  local method='' arg positional=0
  for arg in "$@"; do
    if [[ $arg == -* ]]; then
      continue
    fi
    positional=$((positional + 1))
    if ((positional == 1)) && [[ ${arg,,} =~ ^(get|head|post|put|patch|delete|options)$ ]]; then
      method=$arg
      continue
    fi
    # A request item carries a body, which makes the implicit method a POST.
    if [[ -z $method && $arg != *://* && $arg =~ ^[A-Za-z_][A-Za-z0-9_.-]*:?=. ]]; then
      method=POST
    fi
  done

  if mutating_method "$method"; then
    block_settings "A direct ${method^^} request to a repository control-plane endpoint was requested."
  fi
}

check_wget() {
  if ! has_control_plane_argument "$@"; then
    return 0
  fi

  local method='' arg previous=''
  for arg in "$@"; do
    if [[ $previous == --method ]]; then
      method=$arg
    fi
    case $arg in
    --method=*) method=${arg#--method=} ;;
    --post-data* | --post-file* | --body-data* | --body-file*)
      if [[ -z $method ]]; then
        method=POST
      fi
      ;;
    esac
    previous=$arg
  done

  if mutating_method "$method"; then
    block_settings "A direct ${method^^} request to a repository control-plane endpoint was requested."
  fi
}

evaluate_invocation() {
  local -a words=("$@")
  while ((${#words[@]})) && [[ ${words[0]} =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; do
    words=("${words[@]:1}")
  done
  if ((${#words[@]} == 0)); then
    return 0
  fi

  case "${words[0]##*/}" in
  gh) check_gh "${words[@]:1}" ;;
  curl) check_curl "${words[@]:1}" ;;
  http | https | xh | xhs) check_httpie "${words[@]:1}" ;;
  wget) check_wget "${words[@]:1}" ;;
  esac
}

argv=()
token=''
token_started=0

end_token() {
  if ((token_started)); then
    argv+=("$token")
  fi
  token=''
  token_started=0
}

end_invocation() {
  end_token
  if ((${#argv[@]})); then
    evaluate_invocation "${argv[@]}"
  fi
  argv=()
}

# Split the command line the way the shell would and judge each invocation by
# its own argument vector. Quoted text stays inside the token that carries it,
# so prose that merely names a command never reads as running one.
scan_command_line() {
  local line="$1"
  local length=${#line}
  local index=0
  local quote=''
  local char

  while ((index < length)); do
    char=${line:index:1}
    index=$((index + 1))

    if [[ $quote == "'" ]]; then
      if [[ $char == "'" ]]; then
        quote=''
      else
        token+=$char
      fi
      continue
    fi

    if [[ $quote == '"' ]]; then
      case $char in
      '"') quote='' ;;
      "\\")
        token+=${line:index:1}
        index=$((index + 1))
        ;;
      '$')
        if [[ ${line:index:1} == '(' ]]; then
          # A substitution runs its own commands, so leave the quoted state and
          # tokenize what follows as an invocation of its own.
          end_invocation
          quote=''
          index=$((index + 1))
        else
          token+=$char
        fi
        ;;
      '`')
        end_invocation
        quote=''
        ;;
      *) token+=$char ;;
      esac
      continue
    fi

    case $char in
    "'")
      quote="'"
      token_started=1
      ;;
    '"')
      quote='"'
      token_started=1
      ;;
    "\\")
      token+=${line:index:1}
      index=$((index + 1))
      token_started=1
      ;;
    '$')
      case ${line:index:1} in
      "'")
        quote="'"
        token_started=1
        index=$((index + 1))
        ;;
      '(')
        end_invocation
        index=$((index + 1))
        ;;
      *)
        token+=$char
        token_started=1
        ;;
      esac
      ;;
    '`') end_invocation ;;
    ';' | '&' | '|' | '(' | ')' | $'\n') end_invocation ;;
    '<' | '>') end_token ;;
    ' ' | $'\t' | $'\r') end_token ;;
    *)
      token+=$char
      token_started=1
      ;;
    esac
  done

  end_invocation
}

scan_command_line "$command"
exit 0
