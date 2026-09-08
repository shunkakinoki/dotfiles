#!/usr/bin/env bash
set -euo pipefail

# T3 installs candidates in a private staging directory, then publishes them
# only after npm returns. Prepare the terminal before that handoff. All other
# npm calls, including those made by agent subprocesses, keep their policy.
runtime=""
prefix=""
if [ "${1:-}" = install ]; then
  args=("$@")
  for ((index = 1; index < ${#args[@]}; index++)); do
    case "${args[index]}" in
      --prefix)
        ((index += 1))
        prefix="${args[index]:-}"
        ;;
      --prefix=*) prefix="${args[index]#--prefix=}" ;;
      --) break ;;
    esac
  done
fi
if [ -n "$prefix" ]; then
  candidate="$(realpath -m -- "$prefix")"
  versions="$(realpath -m -- "${T3CODE_HOME:-$HOME/.t3}/runtime/versions")"
  if [ "$(dirname -- "$candidate")" = "$versions" ] &&
    [[ "$(basename -- "$candidate")" == .staging-* ]]; then
    runtime="$candidate"
  fi
fi

if [ -z "$runtime" ]; then
  exec "${T3_REAL_NPM:?}" "$@"
fi

"${T3_REAL_NPM:?}" "$@" --ignore-scripts=true
"${T3_PREPARE_RUNTIME:?}" "$runtime"
