{
  inputs,
  username,
  ...
}:
let
  system = "x86_64-linux";
  nixpkgsConfig = import ../../lib/nixpkgs-config.nix {
    nixpkgsLib = inputs.nixpkgs.lib;
  };
  overlays = import ../../overlays { inherit inputs; };
  pkgs = import inputs.nixpkgs {
    inherit system overlays;
    config = nixpkgsConfig;
  };

  # Check if falcon .deb exists (for conditional import)
  # In CI, this will be false; locally with .deb present, it will be true
  falconDebExists = builtins.pathExists /etc/nixos/falcon-sensor.deb;
in
inputs.nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = {
    inherit inputs username;
  };
  modules = [
    # Framework 13" AMD AI 300 hardware support
    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series

    # Hardware configuration
    ./hardware-configuration.nix

    # Kolide launcher
    ./kolide.nix

    # Keyd configuration
    ../../config/keyd

    # Base system configuration
    (
      { config, lib, ... }:
      {
        # Boot loader (EFI/systemd-boot)
        boot.loader.systemd-boot.enable = true;
        boot.loader.systemd-boot.configurationLimit = 10;
        boot.loader.efi.canTouchEfiVariables = true;
        boot.loader.timeout = 3;

        # Latest kernel for AMD AI 300 support
        boot.kernelPackages = pkgs.linuxPackages_latest;

        # Networking
        networking.hostName = "matic";
        networking.networkmanager.enable = true;
        networking.networkmanager.wifi.powersave = false;

        # Enable fish shell
        programs.fish.enable = true;

        # User configuration
        users.users.${username} = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "networkmanager"
            "video"
          ];
          home = "/home/${username}";
          shell = pkgs.fish;
          initialPassword = "changemeow"; # Change this after first login with: passwd
        };

        security.sudo.wheelNeedsPassword = false;

        # AMD graphics with hardware acceleration
        hardware.graphics.enable = true;
        hardware.graphics.extraPackages = with pkgs; [
          libva
          libva-vdpau-driver
          libvdpau-va-gl
        ];

        # Thunderbolt support
        services.hardware.bolt.enable = true;

        # Fingerprint authentication
        services.fprintd.enable = true;

        # Firmware updates
        services.fwupd.enable = true;

        # Power management
        services.upower.enable = true;
        services.power-profiles-daemon.enable = true;

        # Power button behavior - lock screen instead of shutdown
        services.logind.settings.Login.HandlePowerKey = "lock";

        # Auto timezone (via geolocation)
        services.geoclue2.enable = true;
        services.localtimed.enable = true;

        # Audio (PipeWire)
        services.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          wireplumber.enable = true;
        };
        services.pulseaudio.enable = false;
        security.rtkit.enable = true;

        # Bluetooth
        hardware.bluetooth.enable = true;
        hardware.bluetooth.powerOnBoot = true;

        # Login manager (greetd + tuigreet)
        services.greetd = {
          enable = true;
          settings = {
            default_session = {
              command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --asterisks --sessions /etc/greetd/wayland-sessions";
              user = "greeter";
            };
          };
        };

        # Provide Hyprland session file for tuigreet to discover
        environment.etc."greetd/wayland-sessions/hyprland.desktop".text = ''
          [Desktop Entry]
          Name=Hyprland
          Exec=uwsm start hyprland-uwsm.desktop
          Type=Application
        '';

        programs.hyprland = {
          enable = true;
          package = pkgs.hyprland;
          portalPackage = pkgs.xdg-desktop-portal-hyprland;
          xwayland.enable = true;
          withUWSM = true;
        };

        programs.dconf.enable = true;

        xdg.portal = {
          enable = true;
          extraPortals = with pkgs; [
            xdg-desktop-portal-gtk
          ];
        };

        # WiFi MT7925e fix (disable ASPM)
        boot.extraModprobeConfig = ''
          options mt7925e disable_aspm=1
        '';

        # System packages
        environment.systemPackages = with pkgs; [
          curl
          git
          home-manager
          vim
          wget
          zellij
        ];

        # Enable nix-ld for running dynamically linked binaries (CrowdStrike, Kolide, etc.)
        programs.nix-ld.enable = true;
        programs.nix-ld.libraries = with pkgs; [
          # Common libraries needed by security tools
          glibc
          zlib
          openssl
          curl
          libnl
          libgcc
        ];

        # Nix settings
        nix = {
          settings = {
            experimental-features = [
              "nix-command"
              "flakes"
            ];
            trusted-users = [
              "root"
              username
            ];
          };
          package = pkgs.nixVersions.stable;
        };

        system.stateVersion = "24.11";
      }
    )

    # Fonts
    {
      nixpkgs.pkgs = pkgs;

      fonts.fontconfig.enable = true;
      fonts.packages = with pkgs; [
        inter
        ipaexfont
        ipafont
        joypixels
        nerd-fonts.jetbrains-mono
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
        noto-fonts-color-emoji
      ];
      fonts.fontconfig.defaultFonts = {
        serif = [
          "Noto Serif CJK JP"
          "DejaVu Serif"
        ];
        sansSerif = [
          "Inter"
          "Noto Sans CJK JP"
          "DejaVu Sans"
        ];
        monospace = [
          "JetBrainsMono Nerd Font"
          "Noto Sans Mono CJK JP"
        ];
        emoji = [
          "JoyPixels"
          "Noto Color Emoji"
        ];
      };
    }

    # Home Manager integration
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.backupFileExtension = "hm-backup";
      home-manager.extraSpecialArgs = {
        # Override host detection for matic (isDesktop = true)
        inputs = inputs // {
          host = (import ../../lib/host.nix) // {
            isDesktop = true;
          };
        };
      };
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${username} =
        { config, lib, ... }:
        {
          imports = [
            (import ../../home-manager {
              inherit username;
              # Override host detection for matic (isDesktop = true)
              inputs = inputs // {
                host = (import ../../lib/host.nix) // {
                  isDesktop = true;
                };
              };
              lib = inputs.nixpkgs.lib;
              pkgs = pkgs;
              config = { };
            })
            inputs.timewall.homeManagerModules.default
            ../../config/wallpaper
          ];

          # Dynamic wallpaper (macOS Sequoia-style) via timewall
          services.timewall = {
            enable = true;
            wallpaperPath = "${config.home.homeDirectory}/.local/share/wallpapers/dynamic.heic";
            config = {
              geoclue = {
                enable = true;
                cache_fallback = true;
                timeout = 3000;
              };
              setter = {
                command = [
                  "${pkgs.swww}/bin/swww"
                  "img"
                  "--transition-type"
                  "fade"
                  "--transition-duration"
                  "3"
                  "--transition-fps"
                  "60"
                  "%f"
                ];
              };
              daemon = {
                update_interval_seconds = 300;
              };
            };
          };

          # Agenix configuration for GitHub SSH key
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
              SECRET_FILE="${builtins.toString ../galactica/keys/id_ed25519.age}"
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
        };
    }
  ]
  ++ (if falconDebExists then [ ./falcon.nix ] else [ ]); # CrowdStrike Falcon (only if .deb exists)
}
