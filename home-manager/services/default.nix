{ pkgs }:
let
  docker = import ./docker { inherit pkgs; };
  ollama = import ./ollama { inherit pkgs; };
  dotfilesUpdater = import ./dotfiles-updater;
in
[
  ollama
  dotfilesUpdater
]
