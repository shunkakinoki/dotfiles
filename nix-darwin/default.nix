{
  config,
  pkgs,
  lib,
  isRunner,
  username,
  tailscaleSetFlags,
  ...
}:
let
  dock = import ./config/dock.nix { inherit username; };
  fonts = import ./config/fonts.nix { inherit pkgs; };
  homebrew = import ./config/homebrew.nix { inherit isRunner lib; };
  keyboard = import ./config/keyboard { inherit lib pkgs; };
  networking = import ./config/networking.nix {
    inherit lib pkgs tailscaleSetFlags;
  };
  nix = import ./config/nix.nix;
  security = import ./config/security.nix { inherit username; };
  serviceModules = import ./services { inherit lib isRunner pkgs; };
  system = import ./config/system.nix {
    inherit
      config
      isRunner
      pkgs
      username
      ;
  };
  time = import ./config/time.nix;
in
{
  imports = [
    dock
    fonts
    homebrew
    keyboard
    networking
    nix
    security
    system
    time
  ]
  ++ serviceModules;

}
