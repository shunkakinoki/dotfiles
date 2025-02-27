{
  inputs,
  username,
  hostname ? "x86_64-linux",
  isRunner ? false,
}:
let
  inherit (inputs) nixpkgs home-manager;
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
  configuration =
    { config, lib, ... }:
    {
      boot.loader.grub.enable = true;
      boot.loader.grub.device = "/dev/sda";
      boot.loader.grub.useOSProber = true;
      boot.loader.systemd-boot.configurationLimit = 10;

      networking.hostName = hostname;
      users.users.${username} = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "networkmanager"
        ];
        home = "/home/${username}";
        hashedPassword = if isRunner then "" else null;
        openssh.authorizedKeys.keys = [ ];
      };

      users.users.root.hashedPassword = if isRunner then "" else null;

      security.sudo.wheelNeedsPassword = false;

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
              source = lib.mkForce "$PWD";
              target = lib.mkForce "/mnt/shared";
            };
          };
        };
      };

      environment.systemPackages = with pkgs; [
        curl
        git
        home-manager
        vim
        wget
      ];

      services.getty.autologinUser = lib.mkIf isRunner "root";

      boot.loader.timeout = lib.mkIf isRunner 0;

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

      boot.consoleLogLevel = 7;
      services.journald.extraConfig = "Storage=volatile";
    };
in
nixpkgs.lib.nixosSystem {
  inherit system;
  lib = nixpkgs.lib;
  specialArgs = {
    inherit username isRunner;
  };
  modules = [
    configuration
    {
      fileSystems."/" = {
        device = "/dev/sda1";
        fsType = "ext4";
      };

      nixpkgs.pkgs = pkgs;

      fonts.packages = with pkgs; [
        nerd-fonts.jetbrains-mono
      ];
    }
    home-manager.nixosModules.home-manager
    {
      home-manager.backupFileExtension = "backup";
      home-manager.useUserPackages = true;
      home-manager.users."${username}" = import ../../home-manager {
        inherit system;
        nixpkgs = nixpkgs;
      };
    }
  ];
}
