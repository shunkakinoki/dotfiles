{ lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    nodePackages.bash-language-server
  ];

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

    shellAliases = {
      rm = "gomi";
    };

    bashrcExtra = ''
      # Allow aliases defined in the managed bashrc to expand in non-interactive shells.
      shopt -s expand_aliases

      # Set XDG_RUNTIME_DIR on Linux for consistent socket paths (e.g., zellij)
      if [ "$(uname)" = "Linux" ]; then
          export XDG_RUNTIME_DIR="/run/user/$(id -u)"

          # OpenSSL for cargo builds (rust crates like openssl-sys)
          export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
          export OPENSSL_DIR="${pkgs.openssl.dev}"
          export OPENSSL_LIB_DIR="${pkgs.openssl.out}/lib"
          export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"

          # Native libraries for bun-installed packages (e.g. @oh-my-pi/pi-natives, sharp, keytar)
          export LD_LIBRARY_PATH="${lib.optionalString pkgs.stdenv.isLinux "${pkgs.alsa-lib}/lib:"}${pkgs.glib.out}/lib:${pkgs.libsecret}/lib:${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      fi

      # Go configuration
      export GOPATH="$HOME/go"

      # Last line = highest priority (each export prepends, so last ends up at front of PATH)
      export PATH="$PATH:$HOME/go/bin"
      export PATH="/nix/var/nix/profiles/default/bin:$PATH"
      export PATH="$HOME/.nix-profile/bin:$PATH"
      export PATH="$HOME/.cargo/bin:$PATH"
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="$HOME/.local/scripts:$PATH"
      export PATH="$HOME/.bun/bin:$PATH"
      export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"
      export PATH="/opt/homebrew/bin:$PATH"

      # Worktrunk shell init
      if command -v wt >/dev/null 2>&1; then
        eval "$(wt config shell init bash)"
      fi
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

      # OpenSSL for cargo builds on Linux (available in login shells)
      if [ "$(uname)" = "Linux" ]; then
          export XDG_RUNTIME_DIR="/run/user/$(id -u)"
          export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
          export OPENSSL_DIR="${pkgs.openssl.dev}"
          export OPENSSL_LIB_DIR="${pkgs.openssl.out}/lib"
          export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"

          # Native libraries for bun-installed packages (e.g. @oh-my-pi/pi-natives, sharp, keytar)
          export LD_LIBRARY_PATH="${lib.optionalString pkgs.stdenv.isLinux "${pkgs.alsa-lib}/lib:"}${pkgs.glib.out}/lib:${pkgs.libsecret}/lib:${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      fi

      # Source .bashrc for login shells to get PATH and other settings
      if [ -f ~/.bashrc ]; then
        . ~/.bashrc
      fi
    '';
  };
}
