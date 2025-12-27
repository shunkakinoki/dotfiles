{
  config,
  lib,
  pkgs,
  ...
}:
let
  brewUpgrader = import ./brew-upgrader { inherit pkgs; };
  cliproxyapi = import ./cliproxyapi { inherit config pkgs; };
  codeSyncer = import ./code-syncer { inherit pkgs; };
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
  dotfilesUpdater
  neversslKeepalive
  ollama
  sshAgent
]
