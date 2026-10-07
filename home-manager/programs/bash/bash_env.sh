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

case ":$PATH:" in
*":$HOME/.bun/bin:"*) ;;
*) export PATH="$HOME/.bun/bin:$PATH" ;;
esac

case ":$PATH:" in
*":$HOME/.bun/install/global/node_modules/.bin:"*) ;;
*) export PATH="$HOME/.bun/install/global/node_modules/.bin:$PATH" ;;
esac

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
