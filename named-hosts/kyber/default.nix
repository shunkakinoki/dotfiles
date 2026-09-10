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
  baseHost = import ../../lib/host.nix;
  tailscaleUpArgs = [
    "--reset"
    "--ssh=false"
    "--accept-dns=true"
    "--advertise-exit-node"
  ];
in
home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  extraSpecialArgs = {
    inherit username pkgs;
    isRunner = false;
    inputs = inputs // {
      host = baseHost // {
        isAndor = false;
        isKyber = true;
        isK3sServer = true;
        k3s = baseHost.k3sHostConfigs.kyber;
        nodeName = "kyber";
      };
    };
  };
  modules = [
    agenix.homeManagerModules.default
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
              ${pkgs.bash}/bin/bash ${./activate-backup-files.sh}
            '';
          };
        };

        # Agenix configuration
        age.identityPaths = [ "/home/${username}/.ssh/id_ed25519" ];
        age.secrets = builtins.mapAttrs (
          name: value:
          {
            inherit (value) file;
          }
          // (
            if name == "keys/id_github.age" then
              {
                # Deploy GitHub SSH key to ~/.ssh/ with correct permissions
                path = "/home/${username}/.ssh/id_ed25519_github";
                mode = "0600";
              }
            else
              { }
          )
        ) (import ./secrets.nix);

        # Ensure SSH directory exists before agenix tries to deploy secrets
        home.activation.ensureSshDirectory = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../home-manager/activation/ensure-directory.sh}" "700" "${config.home.homeDirectory}/.ssh"
        '';

        # Ensure agenix config directory exists
        home.activation.ensureAgenixDirectory = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../home-manager/activation/ensure-directory.sh}" "700" "${config.home.homeDirectory}/.config/agenix"
        '';

        # Manually deploy agenix secrets during activation
        # This ensures secrets are deployed even if the agenix activation hook doesn't run properly
        # Source ciphertext is galactica/keys/id_ed25519.age (secrets.nix keys/id_github.age)
        home.activation.deployAgenixSecrets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../home-manager/activation/deploy-agenix-secret.sh}" \
            "${config.home.homeDirectory}/.ssh/id_ed25519_github" \
            "${builtins.toString ../galactica/keys/id_ed25519.age}" \
            "${config.home.homeDirectory}/.ssh/id_ed25519" \
            "${pkgs.rage}/bin/rage"
        '';

        # Declarative OpenSSH hardening (password/root off; pubkey-only)
        home.activation.hardenSshd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate-sshd.sh}"
        '';

        # Fish reads feature flags before config.fish. Store the compatibility
        # flag universally so SSH prompts do not wait for terminal query replies.
        home.activation.disableFishTerminalQueries = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./activate-fish-ssh-compat.sh} ${pkgs.fish}/bin/fish
        '';

        programs.home-manager.enable = true;

        # Review daemons and agent lane shells own disposable work and may be
        # frozen by the host health circuit breaker without interrupting
        # production services. The Herdr server itself is the control plane
        # for every lane, so it lives in its own never-frozen slice and only
        # ordinary panes are moved into orchestration.slice. Explicit recovery
        # panes stay outside the workload slice they must be able to repair.
        home.file.".config/systemd/user/orchestration.slice".source = ./orchestration.slice;
        home.file.".config/systemd/user/herdr.slice".source = ./herdr.slice;
        home.file.".config/systemd/user/roborev.service.d/10-orchestration.conf".source =
          ./orchestration-service.conf;
        xdg.configFile."systemd/user/herdr-server.service".force = true;
        xdg.configFile."systemd/user/default.target.wants/herdr-server.service".force = true;
        systemd.user.services.herdr-server = {
          Unit = {
            Description = "Herdr headless server (coding-agent multiplexer)";
            After = [ "install-npm-globals.service" ];
            X-SwitchMethod = "keep-old";
          };
          Service = {
            Type = "simple";
            ExitType = "cgroup";
            ExecStart = "${pkgs.bash}/bin/bash ${../../home-manager/services/herdr/start.sh} herdr";
            Restart = "on-failure";
            RestartSec = "30s";
            Slice = "herdr.slice";
            Environment = [
              "HERDR_ENV=1"
              "PATH=${config.home.homeDirectory}/.local/bin:${config.home.homeDirectory}/.bun/bin:${config.home.homeDirectory}/.nix-profile/bin:/etc/profiles/per-user/${username}/bin:${
                lib.makeBinPath [
                  pkgs.llm-agents.herdr
                  pkgs.bash
                  pkgs.coreutils
                ]
              }:/usr/local/bin:/usr/bin:/bin"
            ];
          };
          Install.WantedBy = [ "default.target" ];
        };

        # GPG agent configuration
        services.gpg-agent = {
          enable = true;
          enableSshSupport = false;
          pinentry.package = pkgs.pinentry-tty;
          defaultCacheTtl = 94608000; # 3 years
          maxCacheTtl = 94608000; # 3 years
        };

        # GPG_TTY is set in fish shell init instead of sessionVariables
        # because it needs to be evaluated dynamically per shell session
        programs.fish.interactiveShellInit = lib.mkAfter ''
          set -gx GPG_TTY (tty)
        '';

        # Select placement before the interactive shell starts the native agent.
        programs.fish.shellInit = lib.mkAfter ''
          source ${./herdr-pane-scope.fish} ${pkgs.systemd}/bin/systemd-run ${pkgs.fish}/bin/fish ${pkgs.coreutils}/bin/false
        '';

        # Enable XDG directories
        xdg.enable = true;

        # IP forwarding for Tailscale exit node
        home.activation.enableIpForwarding = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate-ip-forwarding.sh}"
        '';

        # Keep Home Manager services responsive when a disconnected SSH/Herdr
        # session leaves CPU- or I/O-heavy validation processes behind.
        home.activation.prioritizeManagedUserServices = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate-user-service-priority.sh}"
        '';

        # Publish every Kyber gateway over tailnet-only HTTPS. Each service
        # needs the serve root, so OpenClaw keeps :443 while T3 and Hermes use
        # dedicated ports. Crabbox runs directly on the host on port 18080.
        home.activation.tailscaleServeGateways = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../home-manager/activation/ensure-tailscale-serve.sh}" 443 18789
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../home-manager/activation/ensure-tailscale-serve.sh}" 8443 3773
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../home-manager/activation/ensure-tailscale-serve.sh}" 9443 9120
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../home-manager/activation/ensure-tailscale-serve.sh}" 10443 18080
        '';

        # Tailscale configuration
        # Using system-level service only (via installSystemService)
        # User services are disabled by leaving serviceConfig empty
        modules.tailscale = {
          enable = true;
          installSystemService = true;
          # Auth key will be provided via agenix secret
          # authKeyFile = config.age.secrets."keys/tailscale-auth.age".path;
          # Exit node kept; explicitly disable Tailscale SSH so long-lived Codex
          # tunnels use OpenSSH over Tailscale instead of the Tailscale SSH proxy.
          extraUpArgs = tailscaleUpArgs;
        };
      }
    )
  ];
}
