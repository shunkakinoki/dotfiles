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
      home.activation.ensureSshDirectory = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        $DRY_RUN_CMD mkdir -p $VERBOSE_ARG ${config.home.homeDirectory}/.ssh
        $DRY_RUN_CMD chmod $VERBOSE_ARG 700 ${config.home.homeDirectory}/.ssh
      '';

      # Manually deploy agenix secrets during activation
      # This ensures secrets are deployed even if the agenix activation hook doesn't run properly
      home.activation.deployAgenixSecrets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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

        # Decrypt and import GPG key for commit signing
        GPG_SECRET_FILE="${builtins.toString ../galactica/keys/gpg.age}"
        if [[ -f "$GPG_SECRET_FILE" ]]; then
          echo "Importing GPG key from agenix..."
          # Check if key is already imported
          if ! ${pkgs.gnupg}/bin/gpg --list-secret-keys | grep -q "C2E97FCFF482925D"; then
            $DRY_RUN_CMD ${pkgs.rage}/bin/rage -d -i ${config.home.homeDirectory}/.ssh/id_ed25519 "$GPG_SECRET_FILE" | ${pkgs.gnupg}/bin/gpg --batch --import
            echo "✅ GPG key imported successfully"
          else
            echo "ℹ️  GPG key already imported"
          fi
        else
          echo "⚠️  Warning: GPG secret file not found at $GPG_SECRET_FILE"
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
        defaultCacheTtl = 1800;
        maxCacheTtl = 7200;
      };

      # Environment variables for GPG
      home.sessionVariables = {
        GPG_TTY = "$(tty)";
      };

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
  ];
}
