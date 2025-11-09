{ pkgs }:
let
  codeSyncer = import ./code-syncer { inherit pkgs; };
  dotfilesUpdater = import ./dotfiles-updater { inherit pkgs; };
  neversslKeepalive = import ./neverssl-keepalive { inherit pkgs; };
  ollama = import ./ollama { inherit pkgs; };
in
[
  codeSyncer
  dotfilesUpdater
  neversslKeepalive
  ollama
]
