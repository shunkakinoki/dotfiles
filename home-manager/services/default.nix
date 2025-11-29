{ pkgs }:
let
  codeSyncer = import ./code-syncer { inherit pkgs; };
  dotfilesUpdater = import ./dotfiles-updater { inherit pkgs; };
  neversslKeepalive = import ./neverssl-keepalive { inherit pkgs; };
  ollama = import ./ollama { inherit pkgs; };
  brewUpgrader = import ./brew-upgrader { inherit pkgs; };
  tailscale = import ./tailscale/default.nix;
in
[
  brewUpgrader
  codeSyncer
  dotfilesUpdater
  neversslKeepalive
  ollama
  tailscale
]
