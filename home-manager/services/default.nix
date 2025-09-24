{ pkgs }:
let
  codeSyncer = import ./code-syncer { inherit pkgs; };
  dotfilesUpdater = import ./dotfiles-updater { inherit pkgs; };
  ollama = import ./ollama { inherit pkgs; };
in
[
  codeSyncer
  dotfilesUpdater
  ollama
]
