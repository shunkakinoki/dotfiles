# From: https://github.com/nix-community/home-manager/blob/master/modules/programs/zsh.nix
{ lib, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
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

    initContent = ''
      # Go configuration
      export GOPATH="$HOME/go"

      # Additional bin paths
      export PATH="$PATH:$GOPATH/bin"
      export PATH="$HOME/.bun/bin:$PATH"
      export PATH="$HOME/.foundry/bin:$PATH"
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="$HOME/.nix-profile/bin:$PATH"
      export PATH="/nix/var/nix/profiles/default/bin:$PATH"
      export PATH="/opt/homebrew/bin:$PATH"

      # FNM (Fast Node Manager) configuration
      export FNM_DIR="$HOME/Library/Application Support/fnm"
      export FNM_COREPACK_ENABLED="false"
      export FNM_ARCH="arm64"
      export FNM_RESOLVE_ENGINES="false"
      export FNM_LOGLEVEL="info"
      export FNM_NODE_DIST_MIRROR="https://nodejs.org/dist"
      export FNM_VERSION_FILE_STRATEGY="local"
    '';
  };
}
