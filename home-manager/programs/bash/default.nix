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
      # Set XDG_RUNTIME_DIR on Linux for consistent socket paths (e.g., zellij)
      # Must be in bashrcExtra (not just profileExtra) so it runs for non-login shells too
      if [ "$(uname)" = "Linux" ]; then
          export XDG_RUNTIME_DIR="/run/user/$(id -u)"
      fi

      # Go configuration
      export GOPATH="$HOME/go"

      # Add additional bin paths
      export PATH="$PATH:$GOPATH/bin"
      export PATH="$HOME/.bun/bin:$PATH"
      export PATH="$HOME/.foundry/bin:$PATH"
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="$HOME/.nix-profile/bin:$PATH"
      export PATH="/nix/var/nix/profiles/default/bin:$PATH"
      export PATH="/opt/homebrew/bin:$PATH"
      export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"
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
