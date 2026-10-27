# Beskar - Ubuntu Linux dedicated T3 Code server
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
  tailscaleUpArgs = [
    "--reset"
    "--operator=${username}"
    "--accept-dns=true"
    "--ssh"
  ];
  sshAuthorizedKeys = import ../ssh-authorized-keys.nix;
  authorizedKeysFile = pkgs.writeText "beskar-authorized-keys" (
    pkgs.lib.concatStringsSep "\n" sshAuthorizedKeys.beskar + "\n"
  );
in
home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  extraSpecialArgs = {
    inherit username pkgs;
    isRunner = false;
    inputs = inputs // {
      host = baseHost // {
        isAndor = false;
        isKyber = false;
        isK3sServer = false;
        k3s = null;
        nodeName = "beskar";
      };
    };
  };
  modules = [
    ../../home-manager/default.nix
    (
      { config, lib, ... }:
      {
        home = {
          inherit username;
          homeDirectory = lib.mkForce "/home/${username}";
          activation.backupExistingFiles = lib.mkForce {
            before = [ "checkLinkTargets" ];
            after = [ ];
            data = ''
              ${pkgs.bash}/bin/bash "${../../hosts/linux/activate-backup-files.sh}" "$newGenPath/home-files"
            '';
          };
          activation.installT3RuntimeLibs = config.lib.dag.entryAfter [ "writeBoundary" ] ''
            $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./activate-t3-runtime-libs.sh}
          '';
          activation.authorizeFleetSsh = config.lib.dag.entryAfter [ "linkGeneration" ] ''
            $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../home-manager/activation/authorize-ssh-keys.sh}" ${authorizedKeysFile} "${config.home.homeDirectory}/.ssh" ${pkgs.openssh}/bin/ssh-keygen
          '';
        };

        programs.home-manager.enable = true;
        xdg.enable = true;

        modules.tailscale = {
          enable = true;
          installSystemService = true;
          extraUpArgs = tailscaleUpArgs;
        };
      }
    )
  ];
}
