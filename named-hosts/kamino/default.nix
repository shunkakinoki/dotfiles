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
  tailscaleUpArgs = [
    "--hostname=${name}"
    "--accept-dns=true"
    # Use Tailscale SSH identity policy for host login; ordinary SSH keys are
    # not the fleet authorization mechanism.
    "--ssh=true"
  ];
  # The relay caps managed T3 Connect tunnels per account, so only these
  # workers get one; the rest stay publish-only and pair over Tailscale.
  t3ManagedTunnelHosts = [ "kamino5" ];
  t3ConnectMode = if builtins.elem name t3ManagedTunnelHosts then "managed" else "publish-only";
  authorizedKey = pkgs.writeText "kamino-authorized-key.pub" (
    (import ../pubkeys.nix).galactica + "\n"
  );
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
            ${pkgs.bash}/bin/bash "${../../hosts/linux/activate-backup-files.sh}" "$newGenPath/home-files"
          '';
        };
        programs.home-manager.enable = true;
        # The installer manages Determinate Nix and garbage collection. Reuse its
        # client during activation instead of mixing Lix with its configuration.
        nix.enable = lib.mkForce false;
        nix.gc.automatic = lib.mkForce false;
        xdg.enable = true;
        systemd.user.startServices = true;
        xdg.configFile."kamino/name".text = "${name}\n";

        home.activation.checkKaminoIdentity = config.lib.dag.entryBefore [ "writeBoundary" ] ''
          ${pkgs.bash}/bin/bash ${./activate.sh} check ${lib.escapeShellArg name} "${config.xdg.configHome}/kamino/name"
        '';
        home.activation.authorizeKaminoSsh = config.lib.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./activate.sh} authorize-ssh ${authorizedKey} "${config.home.homeDirectory}/.ssh" ${pkgs.openssh}/bin/ssh-keygen
        '';
        home.activation.startKaminoUserManager =
          config.lib.dag.entryBetween [ "reloadSystemd" ] [ "writeBoundary" ]
            ''
              export PATH=/usr/bin:$PATH
              $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./activate.sh} user-manager ${lib.escapeShellArg name}
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
              $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./activate.sh} prepare
            '';
        home.activation.configureKaminoTailscale =
          config.lib.dag.entryAfter [ "installTailscaleService" "startKaminoUserManager" ]
            ''
              $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./activate.sh} tailscale ${lib.escapeShellArg name} ${pkgs.tailscale}/bin/tailscale ${lib.escapeShellArgs tailscaleUpArgs}
            '';

        # T3 Connect is provisioned per worker after the npm globals install
        # puts `t3` on PATH. The first activation authorizes with the OAuth
        # device flow; later activations reuse the stored credential. The
        # `t3` shim runs under `#!/usr/bin/env node` and its native binary
        # links libatomic, neither of which the unattended updater provides.
        home.activation.provisionKaminoT3Connect =
          config.lib.dag.entryAfter [ "installNpmGlobals" "startKaminoUserManager" ]
            ''
              export PATH=${config.home.homeDirectory}/.bun/bin:${pkgs.nodejs}/bin:$PATH
              export XDG_RUNTIME_DIR=/run/user/0
              $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./activate.sh} t3-connect ${config.home.homeDirectory}/.bun/bin/t3 ${t3ConnectMode} ${pkgs.stdenv.cc.cc.lib}/lib
            '';

        # Home Manager links the unit into default.target.wants but does not
        # start a pre-existing unit whose definition did not change, and a
        # fresh host can come up with herdr-server enabled yet dead, leaving
        # `herdr agent list` with `server_not_running`. Start it explicitly
        # like the T3 phase does so a worker always answers after activation.
        home.activation.startKaminoHerdrServer = config.lib.dag.entryAfter [ "startKaminoUserManager" ] ''
          export XDG_RUNTIME_DIR=/run/user/0
          $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user daemon-reload || true
          $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user enable --now herdr-server.service || true
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
