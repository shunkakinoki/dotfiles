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
  dolt = ./dolt;
  docker = import ./docker { inherit lib pkgs; };
  firewall = ./firewall;
  dockerPostgres = ./docker-postgres;
  dotfilesUpdater = import ./dotfiles-updater { inherit pkgs; };
  gasTown = import ./gas-town { inherit pkgs; };
  hermes = ./hermes;
  k3s = ./k3s;
  keydApplicationMapper = ./keyd-application-mapper;
  makeUpdater = import ./make-updater { inherit pkgs; };
  moshiHook = ./moshi-hook;
  neversslKeepalive = import ./neverssl-keepalive { inherit pkgs; };
  nightShift = import ./night-shift { inherit pkgs; };
  obsidian = import ./obsidian { inherit config pkgs inputs; };
  ollama = ./ollama;
  qmd = ./qmd;
  openclaw = ./openclaw;
  roborev = ./roborev;
  screenshotClipboard = import ./screenshot-clipboard { inherit pkgs; };
  sshAgent = ./ssh-agent;
  tmuxSessionLogger = import ./tmux-session-logger { inherit pkgs; };
in
[
  brewUpgrader
  cass
  cliproxyapi
  codeSyncer
  dolt
  docker
  dockerPostgres
  firewall
  dotfilesUpdater
  gasTown
  hermes
  k3s
  keydApplicationMapper
  makeUpdater
  moshiHook
  neversslKeepalive
  nightShift
  obsidian
  ollama
  qmd
  openclaw
  roborev
  screenshotClipboard
  sshAgent
  tmuxSessionLogger
]
