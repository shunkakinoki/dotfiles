{
  inputs,
  username,
  ...
}:
import ../../hosts/nixos {
  inherit inputs username;
  hostname = "matic";
  userInitialPassword = "changemeow";
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
        image.fileName = "matic.iso";
        services.getty.helpLine = lib.mkForce "";
      }
    )
  ];
}
