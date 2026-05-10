{
  pkgs,
  lib,
  isRunner,
  username,
  ...
}:
let
  dock = import ./config/dock.nix { inherit username; };
  fonts = import ./config/fonts.nix { inherit pkgs; };
  homebrew = import ./config/homebrew.nix { inherit isRunner lib; };
  keyboard = import ./config/keyboard.nix { inherit lib; };
  networking = import ./config/networking.nix;
  nix = import ./config/nix.nix;
  security = import ./config/security.nix { inherit username; };
  serviceModules = import ./services { inherit lib isRunner pkgs; };
  system = import ./config/system.nix { inherit isRunner pkgs username; };
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
