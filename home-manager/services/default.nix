{
  config,
  lib,
  pkgs,
  ...
}:
let
  brewUpgrader = import ./brew-upgrader { inherit pkgs; };
  cliproxyapi = import ./cliproxyapi;
  codeSyncer = import ./code-syncer { inherit pkgs; };
  docker = import ./docker { inherit lib pkgs; };
  dockerPostgres = import ./docker-postgres { inherit pkgs; };
  dotfilesUpdater = import ./dotfiles-updater { inherit pkgs; };
  makeUpdater = import ./make-updater { inherit pkgs; };
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
  dockerPostgres
  dotfilesUpdater
  makeUpdater
  neversslKeepalive
  ollama
  sshAgent
]
