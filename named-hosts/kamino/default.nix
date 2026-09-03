# Kamino - root-managed Ubuntu worker host, without Kyber production services.
{ inputs }:
let
  username = "root";
  overlays = import ../../overlays { inherit inputs; };
  pkgs = import inputs.nixpkgs {
    system = "x86_64-linux";
    inherit overlays;
    config = import ../../lib/nixpkgs-config.nix { nixpkgsLib = inputs.nixpkgs.lib; };
  };
  host = (import ../../lib/host.nix) // {
    isAndor = false;
    isGalactica = false;
    isKamino = true;
    isKyber = false;
    isMatic = false;
    isViper = false;
    isDesktop = false;
    isK3sServer = false;
    k3s = null;
    nodeName = "kamino";
  };
in
inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  extraSpecialArgs = {
    inherit username pkgs;
    isRunner = false;
    inputs = inputs // {
      inherit host;
    };
  };
  modules = [
    ../../home-manager/default.nix
    (
      { config, lib, ... }:
      {
        home.homeDirectory = lib.mkForce "/root";
        home.activation.backupExistingFiles = lib.mkForce {
          before = [ "checkLinkTargets" ];
          after = [ ];
          data = ''
            ${pkgs.bash}/bin/bash "${../../hosts/linux/activate-backup-files.sh}"
          '';
        };
        programs.home-manager.enable = true;
        xdg.enable = true;

        modules.tailscale = {
          enable = true;
          installSystemService = true;
          extraUpArgs = [
            "--hostname=kamino"
            "--accept-dns=false"
            "--ssh=false"
          ];
        };

        systemd.user.services.herdr-server = {
          Unit = {
            Description = "Herdr headless server";
            X-SwitchMethod = "restart";
          };
          Service = {
            ExecStart = "${pkgs.llm-agents.herdr}/bin/herdr server";
            Restart = "on-failure";
            RestartSec = "5s";
            Environment = [ "HERDR_ENV=1" ];
            EnvironmentFile = [ "-${config.home.homeDirectory}/dotfiles/.env" ];
          };
          Install.WantedBy = [ "default.target" ];
        };
      }
    )
  ];
}
