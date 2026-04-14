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
    (import ../shared/linux-base.nix {
      inherit inputs pkgs username;
      hostname = "viper";
      userInitialPassword = "test";
    })
    (
      {
        lib,
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
