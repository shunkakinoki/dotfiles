# Kamino - root-managed Ubuntu worker host, without Kyber production services.
{
  inputs,
  name ? "kamino",
}:
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
    nodeName = name;
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
        systemd.user.startServices = true;
        xdg.configFile."kamino/name".text = "${name}\n";

        home.activation.checkKaminoIdentity = config.lib.dag.entryBefore [ "writeBoundary" ] ''
          if [ "$(id -u)" != 0 ] || [ "$(cat /proc/1/comm)" != systemd ]; then
            echo "Kamino requires root on a systemd Linux machine." >&2
            exit 1
          fi
          identity="${config.xdg.configHome}/kamino/name"
          if [ -f "$identity" ] && [ "$(cat "$identity")" != ${lib.escapeShellArg name} ]; then
            echo "Refusing to rename an installed Kamino machine." >&2
            exit 1
          fi
        '';
        home.activation.startKaminoUserManager =
          config.lib.dag.entryBetween [ "reloadSystemd" ] [ "writeBoundary" ]
            ''
              $DRY_RUN_CMD /usr/bin/hostnamectl set-hostname ${lib.escapeShellArg name}
              $DRY_RUN_CMD /usr/bin/loginctl enable-linger root
              $DRY_RUN_CMD /usr/bin/systemctl start user@0.service
              export XDG_RUNTIME_DIR=/run/user/0
            '';

        modules.tailscale = {
          enable = true;
          installSystemService = true;
          # Enrollment is explicit; an unattended install must not wait for login.
          extraUpArgs = [ ];
        };
        home.activation.prepareKaminoServiceDirectories =
          config.lib.dag.entryBetween [ "installTailscaleService" ] [ "writeBoundary" ]
            ''
              $DRY_RUN_CMD mkdir -p /etc/sudoers.d
            '';
        home.activation.configureKaminoTailscale =
          config.lib.dag.entryAfter [ "installTailscaleService" "startKaminoUserManager" ]
            ''
              $DRY_RUN_CMD ${pkgs.tailscale}/bin/tailscale set \
                --hostname=${lib.escapeShellArg name} --accept-dns=false --ssh=false
              echo "Tailscale installed. If not enrolled, run: tailscale up --hostname=${name} --accept-dns=false --ssh=false"
            '';

        systemd.user.services.herdr-server = {
          Unit = {
            Description = "Herdr headless server";
            X-SwitchMethod = "restart";
          };
          Service = {
            ExecStart = "${pkgs.llm-agents.herdr}/bin/herdr server";
            Restart = "on-failure";
            RestartSec = "5s";
            Environment = [
              "HERDR_ENV=1"
              "HOME=/root"
              "XDG_RUNTIME_DIR=/run/user/0"
              "SHELL=${pkgs.fish}/bin/fish"
              "PATH=/root/.nix-profile/bin:/etc/profiles/per-user/root/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin"
            ];
            EnvironmentFile = [ "-${config.home.homeDirectory}/dotfiles/.env" ];
          };
          Install.WantedBy = [ "default.target" ];
        };
      }
    )
  ];
}
