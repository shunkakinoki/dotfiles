{ lib, pkgs, ... }:
{
  home.packages =
    with pkgs;
    [
      k9s
      kind
      kubeconform
      kubectl
      kubectx
      kubernetes-helm
      kustomize
    ]
    ++ lib.optionals stdenv.isLinux [
      k3s
    ];
}
