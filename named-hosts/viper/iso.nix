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
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
    (
      { lib, pkgs, ... }:
      {
        # ISO bootstrap - no home-manager available
        environment.systemPackages = with pkgs; [
          curl
          git
          vim
        ];
        # The installer profile enables ZFS; there is no ZFS root to force-import.
        boot.zfs.forceImportRoot = false;
        image.fileName = "viper.iso";
        services.getty.helpLine = lib.mkForce "";
      }
    )
  ];
}
