{ pkgs }:
with pkgs;
[
  aider-chat
  argocd
  claude-code
  codex
  direnv
  dust
  fswatch
  gemini-cli
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
