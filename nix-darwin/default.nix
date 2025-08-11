{
  pkgs,
  lib,
  isRunner,
  username,
  ...
}:
let
  dock = import ./config/dock.nix;
  fonts = import ./config/fonts.nix { inherit pkgs; };
  homebrew = import ./config/homebrew.nix { inherit isRunner; };
  launchd = import ./config/launchd.nix;
  networking = import ./config/networking.nix;
  nix = import ./config/nix.nix;
  security = import ./config/security.nix { inherit username; };
  system = import ./config/system.nix { inherit isRunner pkgs username; };
  time = import ./config/time.nix;
in
{
  imports = [
    dock
    fonts
    homebrew
    launchd
    networking
    nix
    security
    system
    time
  ];
}
