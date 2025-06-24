{ pkgs }:
with pkgs;
[
  argocd
  claude-code
  direnv
  dust
  fswatch
  gh
  ghq
  go
  grc
  jq
  kubectl
  kubectx
  kustomize
  neofetch
  pulumi-bin
  ollama
  rustup
  stern
  uv
]
++ lib.optionals stdenv.isLinux [
  docker
  docker-compose
  helm
]
