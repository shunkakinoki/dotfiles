{
  pkgs,
  lib,
  inputs,
  isRunner,
  username,
  ...
}:
let
  inherit (inputs) env host;
  dock = import ./config/dock.nix;
  fonts = import ./config/fonts.nix { inherit pkgs; };
  homebrew = import ./config/homebrew.nix { inherit isRunner; };
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
    networking
    nix
    security
    system
    time
  ];

  # Clawdbot.app: Install to /Applications/ (galactica only)
  # Use ditto instead of cp -R to preserve all macOS bundle attributes,
  # extended attributes, and resource forks required for Bundle.module lookups
  system.activationScripts.postActivation.text = lib.mkIf (!env.isCI && host.isGalactica) ''
    echo "Installing Clawdbot.app to /Applications..."
    rm -rf /Applications/Clawdbot.app
    ditto "${pkgs.clawdbot-app}/Applications/Clawdbot.app" /Applications/Clawdbot.app
  '';
}
