{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.host) isDesktop;
in
lib.mkIf (pkgs.stdenv.isLinux && isDesktop) {
  # Wallpaper is managed by linux-wallpaperengine via home-manager service
  # configured in named-hosts/matic/default.nix
}
