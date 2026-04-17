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
  dolt = ./dolt;
  docker = import ./docker { inherit lib pkgs; };
  dockerPostgres = ./docker-postgres;
  dotfilesUpdater = import ./dotfiles-updater { inherit pkgs; };
  gasTown = import ./gas-town { inherit pkgs; };
  makeUpdater = import ./make-updater { inherit pkgs; };
  neversslKeepalive = import ./neverssl-keepalive { inherit pkgs; };
  obsidian = import ./obsidian { inherit config pkgs inputs; };
  ollama = import ./ollama { inherit pkgs inputs; };
  qmd = ./qmd;
  openclaw = ./openclaw;
  paperclip = ./paperclip;
  sshAgent = ./ssh-agent;
  tmuxSessionLogger = import ./tmux-session-logger { inherit pkgs; };
in
[
  brewUpgrader
  cass
  cliproxyapi
  codeSyncer
  darkman
  dolt
  docker
  dockerPostgres
  dotfilesUpdater
  gasTown
  makeUpdater
  neversslKeepalive
  obsidian
  ollama
  qmd
  openclaw
  paperclip
  sshAgent
  tmuxSessionLogger
]
