# Kyber - Ubuntu Linux server configuration
{
  inputs,
  username ? "ubuntu",
  system ? "x86_64-linux",
}:
let
  inherit (inputs) home-manager agenix;
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
    inherit inputs username pkgs;
  };
  modules = [
    agenix.homeManagerModules.default
    ../../home-manager/default.nix
    {
      home = {
        username = username;
        homeDirectory = lib.mkForce "/home/${username}";
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
          '';
        };
      };

      # Agenix configuration
      age.identityPaths = [ "/home/${username}/.ssh/id_ed25519" ];
      age.secrets = builtins.mapAttrs (name: value: { file = value.file; }) (import ./secrets.nix);

      programs.home-manager.enable = true;

      # Tailscale configuration
      modules.tailscale = {
        enable = true;
        # Auth key will be provided via agenix secret
        # authKeyFile = config.age.secrets."keys/tailscale-auth.age".path;
        extraUpArgs = [
          "--reset"
          "--accept-dns=false"
        ];
      };
    }
  ];
}
