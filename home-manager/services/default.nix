{
  config,
  lib,
  pkgs,
  ...
}:
let
  brewUpgrader = import ./brew-upgrader { inherit pkgs; };
  cliproxyapi = import ./cliproxyapi { inherit pkgs; };
  codeSyncer = import ./code-syncer { inherit pkgs; };
  docker = import ./docker { inherit config pkgs; };
  dotfilesUpdater = import ./dotfiles-updater { inherit pkgs; };
  neversslKeepalive = import ./neverssl-keepalive { inherit pkgs; };
  ollama = import ./ollama { inherit pkgs; };
  sshAgent = import ./ssh-agent {
    inherit config lib pkgs;
  };
in
[
  brewUpgrader
  cliproxyapi
  codeSyncer
  docker
  dotfilesUpdater
  neversslKeepalive
  ollama
  sshAgent
]
