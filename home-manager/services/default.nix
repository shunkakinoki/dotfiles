{ pkgs }:
let
  codeSyncer = import ./code-syncer { inherit pkgs; };
  dotfilesUpdater = import ./dotfiles-updater { inherit pkgs; };
in
[
  codeSyncer
  dotfilesUpdater
]
