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
in
home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  extraSpecialArgs = {
    inherit inputs username pkgs;
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
        home.activation.ensureSshDirectory = config.lib.dag.entryBefore [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../home-manager/activation/ensure-directory.sh}" "700" "${config.home.homeDirectory}/.ssh"
        '';

        # Ensure agenix config directory exists
        home.activation.ensureAgenixDirectory = config.lib.dag.entryBefore [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../home-manager/activation/ensure-directory.sh}" "700" "${config.home.homeDirectory}/.config/agenix"
        '';

        # Manually deploy agenix secrets during activation
        # This ensures secrets are deployed even if the agenix activation hook doesn't run properly
        home.activation.deployAgenixSecrets = config.lib.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../home-manager/activation/deploy-agenix-secret.sh}" \
            "${config.home.homeDirectory}/.ssh/id_ed25519_github" \
            "${builtins.toString ../galactica/keys/id_github.age}" \
            "${config.home.homeDirectory}/.ssh/id_ed25519" \
            "${pkgs.rage}/bin/rage"
        '';

        # Import GPG key from agenix (all systems with dotfiles)
        # Fails silently if SSH key isn't authorized to decrypt
        home.activation.importGpgKey = config.lib.dag.entryAfter [ "linkGeneration" ] ''
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../home-manager/activation/import-gpg-key.sh}" \
            "${config.home.homeDirectory}/dotfiles/named-hosts/galactica/keys/gpg.age" \
            "${config.home.homeDirectory}/.ssh/id_ed25519" \
            "${config.home.homeDirectory}/.config/agenix" \
            "${pkgs.rage}/bin/rage" \
            "${pkgs.gnupg}/bin/gpg" \
            "C2E97FCFF482925D"
        '';

        programs.home-manager.enable = true;

        # GPG configuration for commit signing
        programs.gpg = {
          enable = true;
          settings = {
            default-key = "shunkakinoki@gmail.com";
          };
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

        # Enable XDG directories
        xdg.enable = true;

        # IP forwarding for Tailscale exit node
        home.activation.enableIpForwarding = config.lib.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate-ip-forwarding.sh}"
        '';

        # Tailscale configuration
        # Using system-level service only (via installSystemService)
        # User services are disabled by leaving serviceConfig empty
        modules.tailscale = {
          enable = true;
          installSystemService = true;
          # Auth key will be provided via agenix secret
          # authKeyFile = config.age.secrets."keys/tailscale-auth.age".path;
          extraUpArgs = [
            "--reset"
            "--accept-dns=false"
            "--advertise-exit-node"
          ];
        };
      }
    )
  ];
}
