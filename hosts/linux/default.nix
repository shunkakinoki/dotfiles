{
  inputs,
  username,
  system ? "x86_64-linux",
  isRunner ? false,
}:
let
  inherit (inputs) home-manager;
  overlays = import ../../overlays { inherit inputs; };
  nixpkgsConfig = import ../../lib/nixpkgs-config.nix {
    nixpkgsLib = inputs.nixpkgs.lib;
  };
  pkgs = import inputs.nixpkgs {
    inherit system overlays;
    config = nixpkgsConfig;
  };
  lib = pkgs.lib;
in
home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  extraSpecialArgs = {
    inherit
      inputs
      username
      isRunner
      pkgs
      ;
  };
  modules = [
    ../../home-manager/default.nix
    {
      home = {
        username = username;
        homeDirectory = lib.mkForce (if username == "root" then "/root" else "/home/${username}");
        activation.backupExistingFiles = lib.mkForce {
          before = [ "checkLinkTargets" ];
          after = [ ];
          data = ''
            # Backup existing bash configuration files
            for file in .bashrc .profile .bash_profile; do
              if [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
                echo "Backing up existing $file to $file.hm-backup"
                mv "$HOME/$file" "$HOME/$file.hm-backup"
              fi
            done

            # Backup existing OpenClaw configuration
            if [ -f "$HOME/.openclaw/openclaw.json" ] && [ ! -L "$HOME/.openclaw/openclaw.json" ]; then
              echo "Backing up existing .openclaw/openclaw.json to .openclaw/openclaw.json.hm-backup"
              mv "$HOME/.openclaw/openclaw.json" "$HOME/.openclaw/openclaw.json.hm-backup"
            fi

            # Clean up old backups in .codex
            find ~/.codex -name "*.hm-backup*" -delete 2>/dev/null || true
          '';
        };
      };
      programs.home-manager.enable = true;
    }
  ];
}
