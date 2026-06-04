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
