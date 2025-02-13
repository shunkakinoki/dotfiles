{ lib, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch.enable = true;

    history = {
      size = 50000;
      save = 50000;
      path = "$HOME/.zsh_history";
      ignoreDups = true;
      share = true;
      extended = true;
    };

    initExtra = ''
      # Initialize Starship
      eval "$(starship init zsh)"

      eval "$(sheldon source)"
      eval "$(direnv hook zsh)"
      eval "$(/opt/homebrew/bin/brew shellenv)"
      source "$HOME/.rye/env"

      # FNM (Fast Node Manager) configuration
      export FNM_DIR="$HOME/Library/Application Support/fnm"
      export FNM_COREPACK_ENABLED="false"
      export FNM_ARCH="arm64"
      export FNM_RESOLVE_ENGINES="false"
      export FNM_LOGLEVEL="info"
      export FNM_NODE_DIST_MIRROR="https://nodejs.org/dist"
      export FNM_VERSION_FILE_STRATEGY="local"

      # OpenRouter API Key
      export OPENROUTER_API_KEY_AVANTE=$(security find-generic-password -a "avante" -s "shunkakinoki" -w)
    '';
  };
}
