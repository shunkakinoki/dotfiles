{
  inputs,
  pkgs,
  username,
  hostname,
  userInitialPassword,
  isoName ? "${hostname}.iso",
}:
{ lib, ... }:
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
    (import ./linux-base.nix {
      inherit
        inputs
        pkgs
        username
        hostname
        userInitialPassword
        ;
    })
  ];

  environment.systemPackages = with pkgs; [
    curl
    git
    vim
  ];

  image.fileName = isoName;
  services.getty.helpLine = lib.mkForce "";
}
