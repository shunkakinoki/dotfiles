# shellcheck shell=bash
# Loaded by non-interactive bash through BASH_ENV.
if [ -z "$BUN_INSTALL" ]; then
  export BUN_INSTALL="$HOME/.bun"
fi

case ":$PATH:" in
*":$HOME/.local/bin:"*) ;;
*) export PATH="$HOME/.local/bin:$PATH" ;;
esac

case ":$PATH:" in
*":$HOME/.cargo/bin:"*) ;;
*) export PATH="$HOME/.cargo/bin:$PATH" ;;
esac

# Move rather than skip: an inherited PATH may list the global node_modules/.bin
# first, and T3 offers in-app provider updates only for CLIs found via ~/.bun/bin.
# The quoted pattern keeps a HOME containing glob characters from never matching.
for _bun_path_dir in "$HOME/.bun/install/global/node_modules/.bin" "$HOME/.bun/bin"; do
  PATH=":$PATH:"
  # One pass misses adjacent duplicates because matches share a colon.
  while [[ $PATH == *":$_bun_path_dir:"* ]]; do
    PATH="${PATH//":$_bun_path_dir:"/:}"
  done
  PATH="${PATH#:}"
  PATH="${PATH%:}"
  export PATH="$_bun_path_dir${PATH:+:$PATH}"
done
unset _bun_path_dir

# Managed T3 dispatch also applies to non-interactive Bash and its child shells.
if [ -x "$HOME/.config/t3/bin/t3" ]; then
  export PATH="$HOME/.config/t3/bin:$PATH"
fi
if [ -x "$HOME/.config/t3/cli.sh" ] &&
  [ -r "${T3CODE_HOME:-$HOME/.t3}/runtime/service-state.json" ]; then
  t3() { "$HOME/.config/t3/cli.sh" "$@"; }
fi

# `bash -c` reads no rc file, only BASH_ENV. The exported guard stops every
# nested bash from re-reading .env, which would clobber per-command overrides
# like `KEY=x bash script.sh`.
if [ -z "${_HM_BASH_ENV_DOTENV_LOADED:-}" ] &&
  [ -f "$HOME/.config/shell/load-env-file.sh" ]; then
  export _HM_BASH_ENV_DOTENV_LOADED=1
  # shellcheck source=/dev/null
  . "$HOME/.config/shell/load-env-file.sh"
  _hm_load_env_file
fi
