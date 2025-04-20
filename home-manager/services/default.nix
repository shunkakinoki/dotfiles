{ pkgs }:
let
  codeSyncer = import ./code-syncer { inherit pkgs; };
  ollama = import ./ollama { inherit pkgs; };
  dotfilesUpdater = import ./dotfiles-updater { inherit pkgs; };
in
[
  codeSyncer
  ollama
  dotfilesUpdater
]
