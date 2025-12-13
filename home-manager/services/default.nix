{ pkgs }:
let
  cliproxyapi = import ./cliproxyapi { inherit pkgs; };
  codeSyncer = import ./code-syncer { inherit pkgs; };
  dotfilesUpdater = import ./dotfiles-updater { inherit pkgs; };
  neversslKeepalive = import ./neverssl-keepalive { inherit pkgs; };
  ollama = import ./ollama { inherit pkgs; };
  brewUpgrader = import ./brew-upgrader { inherit pkgs; };
  sshAgent = import ./ssh-agent.nix;
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
