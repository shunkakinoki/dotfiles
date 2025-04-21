{ pkgs }:
with pkgs;
[
  argocd
  direnv
  dust
  fswatch
  gh
  ghq
  go
  grc
  kubectl
  kubectx
  neofetch
  pulumi-bin
  ollama
  rustup
  stern
]
++ lib.optionals stdenv.isLinux [
  docker
  docker-compose
]
