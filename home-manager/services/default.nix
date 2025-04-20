{ pkgs }:
let
  docker = import ./docker { inherit pkgs; };
  ollama = import ./ollama { inherit pkgs; };
  dotfilesUpdater = import ./dotfiles-updater { inherit pkgs; };
in
[
  ollama
  dotfilesUpdater
]
