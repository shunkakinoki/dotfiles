{ pkgs }:
let
  brewUpgrader = import ./brew-upgrader { inherit pkgs; };
  cliproxyapi = import ./cliproxyapi { inherit pkgs; };
  codeSyncer = import ./code-syncer { inherit pkgs; };
  dotfilesUpdater = import ./dotfiles-updater { inherit pkgs; };
  neversslKeepalive = import ./neverssl-keepalive { inherit pkgs; };
  ollama = import ./ollama { inherit pkgs; };
  sshAgent = import ./ssh-agent { inherit pkgs; };
in
[
  brewUpgrader
  cliproxyapi
  codeSyncer
  dotfilesUpdater
  neversslKeepalive
  ollama
  sshAgent
]
