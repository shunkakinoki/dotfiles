{
  pkgs,
  lib,
  username,
  ...
}:
let
  services = import ./config/services;
  fonts = import ./config/fonts.nix { inherit pkgs; };
  launchd = import ./config/launchd.nix { inherit pkgs; };
  homebrew = import ./config/homebrew.nix;
  networking = import ./config/networking.nix;
  nix = import ./config/nix.nix;
  security = import ./config/security.nix { inherit username; };
  system = import ./config/system.nix { inherit pkgs; };
  time = import ./config/time.nix;
in
{
  imports = [
    fonts
    homebrew
    launchd
    networking
    nix
    security
    services
    system
    time
  ];
}
