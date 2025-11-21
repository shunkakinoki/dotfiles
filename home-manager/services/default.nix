{ pkgs }:
let
  codeSyncer = import ./code-syncer { inherit pkgs; };
  dotfilesUpdater = import ./dotfiles-updater { inherit pkgs; };
  neversslKeepalive = import ./neverssl-keepalive { inherit pkgs; };
  # ollama = import ./ollama { inherit pkgs; };  # FIXME: ollama 0.12.11 has build issues with UI assets, uncomment when fixed
  brewUpgrader = import ./brew-upgrader { inherit pkgs; };
in
[
  brewUpgrade
  codeSyncer
  dotfilesUpdater
  neversslKeepalive
  # ollama
]
