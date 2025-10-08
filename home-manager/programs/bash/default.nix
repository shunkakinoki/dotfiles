{ lib, pkgs, ... }:
{
  programs.bash = {
    enable = true;
    enableCompletion = true;

    historySize = -1;
    historyFileSize = -1;
    historyControl = [
      "ignoredups"
      "ignorespace"
    ];
    historyIgnore = [
      "ls"
      "cd"
      "exit"
    ];

    sessionVariables = {
      # Go configuration
      GOPATH = "$HOME/go";

      # FNM (Fast Node Manager) configuration
      FNM_DIR =
        if pkgs.stdenv.isDarwin then "$HOME/Library/Application Support/fnm" else "$HOME/.local/share/fnm";
      FNM_COREPACK_ENABLED = "false";
      FNM_ARCH = if pkgs.stdenv.hostPlatform.isAarch64 then "arm64" else "x64";
      FNM_RESOLVE_ENGINES = "false";
      FNM_LOGLEVEL = "info";
      FNM_NODE_DIST_MIRROR = "https://nodejs.org/dist";
      FNM_VERSION_FILE_STRATEGY = "local";
    };

    bashrcExtra = ''
      # Initialize Starship
      eval "$(starship init bash)"

      # Initialize direnv
      eval "$(direnv hook bash)"

      # Initialize Homebrew
      eval "$(/opt/homebrew/bin/brew shellenv)"

      # Initialize Rye
      if [ -f "$HOME/.rye/env" ]; then
        source "$HOME/.rye/env"
      fi

      # Add Go bin to PATH
      export PATH="$PATH:$GOPATH/bin"

      # Add Bun bin to PATH
      export PATH="$HOME/.bun/bin:$PATH"
    '';

    profileExtra = ''
      # Nix
      if [ -e ~/.nix-profile/etc/profile.d/nix.sh ]; then
        . ~/.nix-profile/etc/profile.d/nix.sh
      fi

      # Nix daemon
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi
    '';
  };
}
