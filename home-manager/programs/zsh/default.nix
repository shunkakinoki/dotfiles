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

      # Additional bin paths
      export PATH="$PATH:$GOPATH/bin"
      export PATH="$HOME/.bun/bin:$PATH"
      export PATH="$HOME/.cargo/bin:$PATH"
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="$HOME/.nix-profile/bin:$PATH"
      export PATH="/nix/var/nix/profiles/default/bin:$PATH"
      export PATH="/opt/homebrew/bin:$PATH"
      export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"

      # FNM (Fast Node Manager) configuration
      export FNM_DIR="$HOME/Library/Application Support/fnm"
      export FNM_COREPACK_ENABLED="false"
      export FNM_ARCH="arm64"
      export FNM_RESOLVE_ENGINES="false"
      export FNM_LOGLEVEL="info"
      export FNM_NODE_DIST_MIRROR="https://nodejs.org/dist"
      export FNM_VERSION_FILE_STRATEGY="local"

      # Worktrunk shell init
      eval "$(wt config shell init zsh)"
    '';
  };
}
