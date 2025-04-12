{ pkgs }:
with pkgs;
[
  argocd
  direnv
  dust
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
++ (if pkgs.stdenv.isLinux then [ k3s ] else [ ])
