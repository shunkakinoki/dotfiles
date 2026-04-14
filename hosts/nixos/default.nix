# Shared NixOS system builder.
# All NixOS hosts call this with their specific modules.
# When no modules are passed, includes generic config (x86_64-linux/runner).
{
  inputs,
  username,
  hostname ? "x86_64-linux",
  isRunner ? false,
  system ? "x86_64-linux",
  stateVersion ? "24.11",
  userExtraGroups ? [ ],
  userInitialPassword ? null,
  modules ? null,
  specialArgs ? { },
}:
let
  nixpkgsConfig = import ../../lib/nixpkgs-config.nix {
    nixpkgsLib = inputs.nixpkgs.lib;
  };
  overlays = import ../../overlays { inherit inputs; };
  pkgs = import inputs.nixpkgs {
    inherit system overlays;
    config = nixpkgsConfig;
  };

  # Shared base: every NixOS host gets this
  baseModule =
    { lib, ... }:
    {
      networking.hostName = hostname;
      networking.networkmanager.enable = true;

      programs.fish.enable = true;

      users.users.${username} = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "networkmanager"
        ]
        ++ userExtraGroups;
        home = "/home/${username}";
        shell = pkgs.fish;
      }
      // lib.optionalAttrs (userInitialPassword != null) {
        initialPassword = userInitialPassword;
      };

      security.sudo.wheelNeedsPassword = false;

      nix = {
        channel.enable = false;
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          nix-path = lib.mkForce "nixpkgs=/etc/nix/inputs/nixpkgs";
          substituters = [
            "https://cache.nixos.org"
          ];
          trusted-users = [
            "root"
            username
            "@wheel"
          ];
        };
        package = pkgs.nixVersions.stable;
      };

      environment.etc."nix/inputs/nixpkgs".source = "${inputs.nixpkgs}";

      system.stateVersion = stateVersion;
    };

  # Generic config for x86_64-linux/runner (used when modules == null)
  genericModules = [
    (
      { lib, ... }:
      {
        boot.loader.grub.enable = true;
        boot.loader.grub.device = "/dev/sda";
        boot.loader.grub.useOSProber = true;
        boot.loader.systemd-boot.configurationLimit = 10;

        users.users.${username} = {
          hashedPassword = if isRunner then "" else null;
          openssh.authorizedKeys.keys = [ ];
        };

        users.users.root.hashedPassword = if isRunner then "" else null;

        virtualisation = lib.mkIf isRunner {
          vmware.guest.enable = true;
          libvirtd.enable = true;
          virtualbox.guest.enable = false;
          vmVariant = {
            virtualisation = {
              memorySize = 4096;
              cores = 2;
            };
            virtualisation.graphics = false;
            virtualisation.sharedDirectories = {
              shared = {
                source = "$PWD";
                target = "/mnt/shared";
              };
            };
          };
        };

        services.getty.autologinUser = lib.mkIf isRunner "root";
        boot.loader.timeout = lib.mkIf isRunner 0;

        boot.consoleLogLevel = 7;
        services.journald.extraConfig = "Storage=volatile";

        fileSystems."/" = {
          device = "/dev/sda1";
          fsType = "ext4";
        };

        fonts.packages = with pkgs; [
          nerd-fonts.jetbrains-mono
        ];
      }
    )
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.backupFileExtension = "hm-backup";
      home-manager.extraSpecialArgs = { inherit inputs; };
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users."${username}" = import ../../home-manager {
        inherit inputs username;
        inherit (inputs.nixpkgs) lib;
        inherit pkgs;
        config = { };
      };
    }
  ];
in
inputs.nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = {
    inherit inputs username isRunner;
  }
  // specialArgs;
  modules = [
    { nixpkgs.pkgs = pkgs; }
    baseModule
  ]
  ++ (if modules == null then genericModules else modules);
}
