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

    # Base system configuration
    (
      { config, lib, ... }:
      {
        # Boot loader (EFI/systemd-boot)
        boot.loader.systemd-boot.enable = true;
        boot.loader.systemd-boot.configurationLimit = 10;
        boot.loader.efi.canTouchEfiVariables = true;
        boot.loader.grub.enable = false;
        boot.loader.timeout = 3;

        # TPM2 auto-unlock for LUKS disk encryption
        boot.initrd.systemd.enable = true;
        boot.initrd.luks.devices."luks-4a2ddfc4-1a40-4e18-99f5-250baf72b4ac".crypttabExtraOpts = [
          "tpm2-device=auto"
        ];

        # Pin kernel to 6.18 for CrowdStrike Falcon compatibility (RFM on 6.19)
        boot.kernelPackages = pkgs.linuxPackages_6_18;

        # AMD power management kernel params
        boot.kernelParams = [
          "amdgpu.abmlevel=3" # auto backlight management
          "amdgpu.runpm=1" # runtime power management for GPU
          "amd_pstate=active" # AMD P-state driver (better than acpi-cpufreq)
        ];

        # Networking
        networking.hostName = "matic";
        networking.networkmanager.enable = true;
        networking.networkmanager.wifi.powersave = true;

        # Enable fish shell
        programs.fish.enable = true;

        # User configuration
        users.users.${username} = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "networkmanager"
            "input"
            "video"
            "docker"
          ];
          home = "/home/${username}";
          shell = pkgs.fish;
          initialPassword = "changemeow"; # Change this after first login with: passwd
        };

        # Docker
        virtualisation.docker.enable = true;

        security.sudo.wheelNeedsPassword = false;
        # Keyd configuration (Linux desktop only)
        services.keyd.enable = true;
        users.groups.keyd = { };
        systemd.services.keyd.serviceConfig = {
          CapabilityBoundingSet = [ "CAP_SETGID" ];
          AmbientCapabilities = [ "CAP_SETGID" ];
        };
        systemd.services.keyd.restartTriggers = [
          (builtins.hashFile "sha256" ../../config/keyd/default.conf)
        ];
        environment.etc."keyd/default.conf".source = ../../config/keyd/default.conf;

        # Input remapping (xremap)
        hardware.uinput.enable = true;
        services.udev.extraRules = ''
          KERNEL=="uinput", GROUP="input", TAG+="uaccess", MODE:="0660", OPTIONS+="static_node=uinput"
          KERNEL=="event*", ATTRS{name}=="keyd virtual keyboard", GROUP="input", MODE:="0660"
          KERNEL=="event*", ATTRS{name}=="keyd virtual pointer", GROUP="input", MODE:="0660"
        '';

        # AMD graphics with hardware acceleration
        hardware.graphics.enable = true;
        hardware.graphics.extraPackages = with pkgs; [
          libva
          libva-vdpau-driver
          libvdpau-va-gl
        ];

        # Thunderbolt support
        services.hardware.bolt.enable = true;

        # GNOME Keyring - auto-unlocks GPG key on login via PAM
        services.gnome.gnome-keyring.enable = true;

        # Fingerprint authentication
        services.fprintd.enable = true;
        security.pam.services.greetd = {
          fprintAuth = true;
          enableGnomeKeyring = true;
        };
        security.pam.services.hyprlock = {
          fprintAuth = true;
        };
        security.pam.services.sudo = {
          fprintAuth = true;
        };

        # Firmware updates
        services.fwupd.enable = true;

        # Power management
        powerManagement.enable = true;
        powerManagement.powertop.enable = true;
        services.upower.enable = true;
        services.power-profiles-daemon.enable = false;
        services.auto-cpufreq = {
          enable = true;
          settings = {
            battery = {
              governor = "powersave";
              turbo = "never";
            };
            charger = {
              governor = "performance";
              turbo = "auto";
            };
          };
        };

        # Power button behavior - lock screen instead of shutdown
        services.logind.settings.Login.HandlePowerKey = "lock";
        # On battery: suspend immediately when lid closed
        # On AC: ignore lid close — let hypridle's 30-min idle timer handle suspension
        services.logind.settings.Login.HandleLidSwitch = "suspend";
        services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";

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

        # Disk management
        services.gvfs.enable = true; # For automounting external drives in Nautilus and managing disk permissions
        services.udisks2.enable = true; # For better integration with external drives, including NTFS support and proper permissions handling

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

        # Steam (for Wallpaper Engine assets)
        programs.steam.enable = true;

        programs.dconf.enable = true;

        xdg.portal = {
          enable = true;
          extraPortals = with pkgs; [
            xdg-desktop-portal-gtk
          ];
          config = {
            hyprland = {
              default = [
                "hyprland"
                "gtk"
              ];
              "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
            };
          };
        };

        # WiFi MT7925e fix (disable ASPM)
        boot.extraModprobeConfig = ''
          options mt7925e disable_aspm=1
        '';

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
          ];

          # Animated wallpaper via Wallpaper Engine
          services.linux-wallpaperengine = {
            enable = true;
            assetsPath = "${config.home.homeDirectory}/.local/share/Steam/steamapps/common/wallpaper_engine/assets";
            wallpapers = [
              {
                monitor = "eDP-1";
                wallpaperId = "3602362048";
                scaling = "fill";
                fps = 30;
                audio.silent = true;
              }
            ];
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
                if $DRY_RUN_CMD ${pkgs.rage}/bin/rage -d -i ${config.home.homeDirectory}/.ssh/id_ed25519 "$SECRET_FILE" -o ${config.home.homeDirectory}/.ssh/id_ed25519_github 2>/dev/null; then
                  $DRY_RUN_CMD chmod $VERBOSE_ARG 0600 ${config.home.homeDirectory}/.ssh/id_ed25519_github
                  echo "✅ GitHub SSH key deployed successfully"
                else
                  echo "⚠️  Warning: SSH key not authorized to decrypt — skipping"
                fi
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

          # Auto-unlock GNOME Keyring on login via TPM2-backed credential
          # Setup (run once):
          #   mkdir -p ~/.config/credstore.encrypted
          #   echo -n "your-keyring-password" | systemd-creds encrypt \
          #     --name=gnome-keyring --with-key=tpm2+host \
          #     - ~/.config/credstore.encrypted/gnome-keyring.cred
          systemd.user.services.gnome-keyring-unlock = {
            Unit = {
              Description = "Unlock GNOME Keyring via TPM2 credential";
              After = [ "graphical-session-pre.target" ];
              PartOf = [ "graphical-session-pre.target" ];
              ConditionPathExists = "%h/.config/credstore.encrypted/gnome-keyring.cred";
            };
            Service = {
              Type = "oneshot";
              LoadCredentialEncrypted = "gnome-keyring:%h/.config/credstore.encrypted/gnome-keyring.cred";
              ExecStart = "${pkgs.writeShellScript "unlock-keyring" ''
                cat "$CREDENTIALS_DIRECTORY/gnome-keyring" | \
                  ${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --unlock
              ''}";
              RemainAfterExit = "yes";
            };
            Install = {
              WantedBy = [ "graphical-session-pre.target" ];
            };
          };

          # GPG agent configuration
          services.gpg-agent = {
            enable = true;
            enableSshSupport = false;
            pinentry.package = pkgs.pinentry-gnome3;
            defaultCacheTtl = 2147483647; # max (effectively forever)
            maxCacheTtl = 2147483647; # max (effectively forever)
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
