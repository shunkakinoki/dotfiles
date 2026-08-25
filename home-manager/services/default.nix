{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  brewUpgrader = import ./brew-upgrader { inherit pkgs; };
  caam = import ./caam;
  cass = import ./cass { inherit pkgs; };
  cliproxyapi = import ./cliproxyapi;
  cpaManagerPlus = ./cpa-manager-plus;
  codeSyncer = import ./code-syncer { inherit pkgs; };
  crabbox = ./crabbox;
  dolt = ./dolt;
  docker = import ./docker { inherit lib pkgs; };
  firewall = ./firewall;
  dockerPostgres = ./docker-postgres;
  dotfilesUpdater = import ./dotfiles-updater { inherit inputs pkgs; };
  gasTown = import ./gas-town { inherit pkgs; };
  hermes = ./hermes;
  k3s = ./k3s;
  keydApplicationMapper = ./keyd-application-mapper;
  makeUpdater = import ./make-updater { inherit pkgs; };
  mempalaceExporter = import ./mempalace-exporter { inherit pkgs; };
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
  t3Connect = import ./t3-connect { inherit pkgs; };
  tmuxSessionLogger = import ./tmux-session-logger { inherit pkgs; };
  tokscale = import ./tokscale { inherit config lib pkgs; };
in
[
  brewUpgrader
  caam
  cass
  cliproxyapi
  cpaManagerPlus
  codeSyncer
  crabbox
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
  mempalaceExporter
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
  t3Connect
  tmuxSessionLogger
  tokscale
]
