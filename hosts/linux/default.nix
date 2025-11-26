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

            # Clean up old backups in .codex
            find ~/.codex -name "*.hm-backup*" -delete 2>/dev/null || true
          '';
        };
      };
      programs.home-manager.enable = true;

      nix = {
        package = pkgs.nixVersions.stable;
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          substituters = [
            "https://cache.nixos.org"
            "https://devenv.cachix.org"
            "https://cachix.cachix.org"
          ];
          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
            "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
          ];
        };
      };
    }
  ];
}
