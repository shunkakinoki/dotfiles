# Andor - Ubuntu Linux external API k3s server
{
  inputs,
  username ? "ubuntu",
  system ? "x86_64-linux",
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
  baseHost = import ../../lib/host.nix;
in
home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  extraSpecialArgs = {
    inherit username pkgs;
    isRunner = false;
    inputs = inputs // {
      host = baseHost // {
        isAndor = true;
        isKyber = false;
        isK3sServer = true;
        k3s = baseHost.k3sHostConfigs.andor;
        nodeName = "andor";
      };
    };
  };
  modules = [
    ../../home-manager/default.nix
    (
      { lib, ... }:
      {
        home = {
          inherit username;
          homeDirectory = lib.mkForce "/home/${username}";
          activation.backupExistingFiles = lib.mkForce {
            before = [ "checkLinkTargets" ];
            after = [ ];
            data = ''
              ${pkgs.bash}/bin/bash "${../../hosts/linux/activate-backup-files.sh}"
            '';
          };
        };

        programs.home-manager.enable = true;
        xdg.enable = true;

        modules.tailscale = {
          enable = true;
          installSystemService = true;
          extraUpArgs = [
            "--reset"
            "--accept-dns=false"
            "--ssh"
          ];
        };
      }
    )
  ];
}
