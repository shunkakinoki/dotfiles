{ lib, pkgs, ... }:
{
  home.packages =
    with pkgs;
    [
      k9s
      kind
      kubeconform
      kubectx
      kubernetes-helm
      kustomize
    ]
    ++ lib.optionals stdenv.isLinux [
      k3s
    ]
    ++ lib.optionals (!stdenv.isLinux) [
      kubectl
    ];
}
