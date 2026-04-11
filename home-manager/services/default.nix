{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  brewUpgrader = import ./brew-upgrader { inherit pkgs; };
  cass = import ./cass { inherit pkgs; };
  cliproxyapi = import ./cliproxyapi;
  codeSyncer = import ./code-syncer { inherit pkgs; };
  darkman = import ./darkman { inherit pkgs; };
  docker = import ./docker { inherit lib pkgs; };
  dockerPostgres = import ./docker-postgres { inherit pkgs; };
  dotfilesUpdater = import ./dotfiles-updater { inherit pkgs; };
  gasTown = import ./gt-daemon { inherit pkgs; };
  makeUpdater = import ./make-updater { inherit pkgs; };
  neversslKeepalive = import ./neverssl-keepalive { inherit pkgs; };
  ollama = import ./ollama { inherit pkgs inputs; };
  sshAgent = import ./ssh-agent {
    inherit config lib pkgs;
  };
  tmuxSessionLogger = import ./tmux-session-logger { inherit pkgs; };
in
[
  brewUpgrader
  cass
  cliproxyapi
  codeSyncer
  darkman
  docker
  dockerPostgres
  dotfilesUpdater
  gasTown
  makeUpdater
  neversslKeepalive
  ollama
  sshAgent
  tmuxSessionLogger
]
