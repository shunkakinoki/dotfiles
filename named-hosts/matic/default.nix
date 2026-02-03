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

        # User configuration
        users.users.${username} = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "networkmanager"
            "video"
          ];
          home = "/home/${username}";
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

        # Desktop environment (GNOME)
        services.xserver.enable = true;
        services.xserver.displayManager.gdm.enable = true;
        services.xserver.desktopManager.gnome.enable = true;

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
      nixpkgs.config.joypixels.acceptLicense = true;

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
      home-manager.extraSpecialArgs = { inherit inputs; };
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${username} = import ../../home-manager {
        inherit inputs username;
        lib = inputs.nixpkgs.lib;
        pkgs = pkgs;
        config = { };
      };
    }
  ];
}
