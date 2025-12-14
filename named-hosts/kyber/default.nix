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
    (
      { config, lib, ... }:
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
        age.secrets = builtins.mapAttrs (
          name: value:
          {
            file = value.file;
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
          $DRY_RUN_CMD mkdir -p $VERBOSE_ARG ${config.home.homeDirectory}/.ssh
          $DRY_RUN_CMD chmod $VERBOSE_ARG 700 ${config.home.homeDirectory}/.ssh
        '';

        # Ensure agenix config directory exists
        home.activation.ensureAgenixDirectory = config.lib.dag.entryBefore [ "writeBoundary" ] ''
          $DRY_RUN_CMD mkdir -p $VERBOSE_ARG ${config.home.homeDirectory}/.config/agenix
          $DRY_RUN_CMD chmod $VERBOSE_ARG 700 ${config.home.homeDirectory}/.config/agenix
        '';

        # Manually deploy agenix secrets during activation
        # This ensures secrets are deployed even if the agenix activation hook doesn't run properly
        home.activation.deployAgenixSecrets = config.lib.dag.entryAfter [ "writeBoundary" ] ''
          # Decrypt and deploy GitHub SSH key if it doesn't exist
          if [[ ! -f "${config.home.homeDirectory}/.ssh/id_ed25519_github" ]]; then
            echo "Deploying GitHub SSH key from agenix..."
            SECRET_FILE="${builtins.toString ../galactica/keys/id_github.age}"
            if [[ -f "$SECRET_FILE" ]]; then
              $DRY_RUN_CMD ${pkgs.rage}/bin/rage -d -i ${config.home.homeDirectory}/.ssh/id_ed25519 "$SECRET_FILE" -o ${config.home.homeDirectory}/.ssh/id_ed25519_github
              $DRY_RUN_CMD chmod $VERBOSE_ARG 0600 ${config.home.homeDirectory}/.ssh/id_ed25519_github
              echo "✅ GitHub SSH key deployed successfully"
            else
              echo "⚠️  Warning: Secret file not found at $SECRET_FILE"
            fi
          fi
        '';

        # Import GPG key from agenix (all systems with dotfiles)
        # Fails silently if SSH key isn't authorized to decrypt
        home.activation.importGpgKey = config.lib.dag.entryAfter [ "linkGeneration" ] ''
          $VERBOSE_ECHO "🔑 Starting GPG key import process..."
          GPG_SECRET_FILE="${config.home.homeDirectory}/dotfiles/named-hosts/galactica/keys/gpg.age"
          GPG_TEMP_FILE="${config.home.homeDirectory}/.config/agenix/gpg.key"

          # Create agenix directory if it doesn't exist
          mkdir -p "${config.home.homeDirectory}/.config/agenix"

          if [[ -f "$GPG_SECRET_FILE" ]]; then
            # Check if key is already imported
            if ! ${pkgs.gnupg}/bin/gpg --list-secret-keys 2>/dev/null | grep -q "C2E97FCFF482925D"; then
              echo "Importing GPG key from agenix..."
              # Try to decrypt - will fail silently if SSH key isn't authorized
              if ${pkgs.rage}/bin/rage -d -i ${config.home.homeDirectory}/.ssh/id_ed25519 -o "$GPG_TEMP_FILE" "$GPG_SECRET_FILE" 2>/dev/null; then
                ${pkgs.gnupg}/bin/gpg --batch --import "$GPG_TEMP_FILE" 2>/dev/null
                rm -f "$GPG_TEMP_FILE"
                echo "✅ GPG key imported successfully"
              fi
            else
              $VERBOSE_ECHO "ℹ️  GPG key already imported"
            fi
          fi
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
          ];
        };
      }
    )
  ];
}
