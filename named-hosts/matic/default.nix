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
        services.power-profiles-daemon.enable = true;

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
        services.blueman.enable = true;

        # Desktop environment (Hyprland)
        services.xserver.enable = true;
        services.displayManager.gdm.enable = true;
        services.displayManager.defaultSession = "hyprland";
        services.desktopManager.gnome.enable = false;

        programs.hyprland = {
          enable = true;
          xwayland.enable = true;
          withUWSM = true;
        };

        programs.dconf.enable = true;

        xdg.portal = {
          enable = true;
          extraPortals = with pkgs; [
            xdg-desktop-portal-hyprland
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
            substituters = [
              "https://cache.nixos.org"
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
        };
    }
  ]
  ++ (if falconDebExists then [ ./falcon.nix ] else [ ]); # CrowdStrike Falcon (only if .deb exists)
}
