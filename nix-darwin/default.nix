{
  pkgs,
  lib,
  username,
  ...
}:
let
  fonts = import ./config/fonts.nix { inherit pkgs; };
  homebrew = import ./config/homebrew.nix { inherit username; };
  launchd = import ./config/launchd.nix { inherit pkgs; };
  networking = import ./config/networking.nix;
  nix = import ./config/nix.nix;
  security = import ./config/security.nix { inherit username; };
  system = import ./config/system.nix { inherit pkgs username; };
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
    system
    time
  ];
}
