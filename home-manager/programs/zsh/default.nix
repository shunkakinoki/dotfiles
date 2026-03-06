# From: https://github.com/nix-community/home-manager/blob/master/modules/programs/zsh.nix
{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    enableCompletion = true;
    autocd = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch.enable = true;

    history = {
      size = -1;
      save = -1;
      path = "$HOME/.zsh_history";
      ignoreDups = true;
      share = true;
      extended = true;
    };

    # envExtra goes to .zshenv (always sourced)
    envExtra = ''
      # Load Homebrew environment
      if [ -f /opt/homebrew/bin/brew ]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
      fi

      # Set XDG_RUNTIME_DIR on Linux for consistent socket paths (e.g., zellij)
      if [ "$(uname)" = "Linux" ]; then
          export XDG_RUNTIME_DIR="/run/user/$(id -u)"

          # OpenSSL for cargo builds (rust crates like openssl-sys)
          export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
          export OPENSSL_DIR="${pkgs.openssl.dev}"
          export OPENSSL_LIB_DIR="${pkgs.openssl.out}/lib"
          export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"
      fi
    '';

    initContent = ''
      # Go configuration
      export GOPATH="$HOME/go"

      # First line = highest priority
      _paths="/opt/homebrew/bin"
      _paths="$_paths:/opt/homebrew/opt/postgresql@18/bin"
      _paths="$_paths:$HOME/.bun/bin"
      _paths="$_paths:$HOME/.local/bin"
      _paths="$_paths:$HOME/.cargo/bin"
      _paths="$_paths:$HOME/go/bin"
      _paths="$_paths:$HOME/.nix-profile/bin"
      _paths="$_paths:/nix/var/nix/profiles/default/bin"
      export PATH="$_paths:$PATH"
      unset _paths

      # FNM (Fast Node Manager) configuration
      export FNM_DIR="$HOME/Library/Application Support/fnm"
      export FNM_COREPACK_ENABLED="false"
      export FNM_ARCH="arm64"
      export FNM_RESOLVE_ENGINES="false"
      export FNM_LOGLEVEL="info"
      export FNM_NODE_DIST_MIRROR="https://nodejs.org/dist"
      export FNM_VERSION_FILE_STRATEGY="local"

      # Worktrunk shell init
      if command -v wt >/dev/null 2>&1; then
        eval "$(wt config shell init zsh)"
      fi
    '';
  };
}
