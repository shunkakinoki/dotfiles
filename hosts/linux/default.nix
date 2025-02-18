{
  pkgs,
  inputs,
  username,
  hostname ? "x86_64-linux",
  isRunner ? false,
}:
let
  inherit (inputs) nixpkgs home-manager;
  system = "x86_64-linux";
  configuration =
    { ... }:
    {
      boot.loader.grub.enable = true;
      boot.loader.grub.device = "/dev/sda";
      boot.loader.grub.useOSProber = true;
      boot.loader.systemd-boot.configurationLimit = 10;

      networking.hostName = hostname;
      users.users.${username} = {
        isNormalUser = true;
        home = "/Users/${username}";
      };
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

      font.packages = with pkgs [
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
