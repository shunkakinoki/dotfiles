{
  inputs,
  username,
  ...
}:
import ../../hosts/nixos {
  inherit inputs username;
  hostname = "viper";
  userInitialPassword = "test";
  modules = [
    (
      {
        lib,
        pkgs,
        modulesPath,
        ...
      }:
      {
        imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

        boot.loader.grub.enable = true;
        boot.loader.grub.device = "/dev/vda";
        boot.loader.timeout = 3;

        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };

        # No home-manager on this host; install essentials at system level
        environment.systemPackages = with pkgs; [
          curl
          git
          vim
        ];

        services.openssh.enable = true;

        virtualisation.vmVariant = {
          virtualisation = {
            graphics = false;
            memorySize = 4096;
            cores = 4;
          };
          users.users.${username}.initialPassword = lib.mkForce "test";
        };
      }
    )
  ];
}
