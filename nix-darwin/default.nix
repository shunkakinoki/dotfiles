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
  # disable homebrew for runner
  homebrew = if username != "runner" then (import ./config/homebrew.nix) else {};
  networking = import ./config/networking.nix;
  nix = import ./config/nix.nix;
  security = import ./config/security.nix { inherit username; };
  system = import ./config/system.nix { inherit pkgs; };
  time = import ./config/time.nix;
in
{
  imports = [
    fonts
    launchd
    networking
    nix
    security
    services
    system
    time
  ];

  # Conditionally include homebrew configuration
  inherit (homebrew) homebrew;
}
