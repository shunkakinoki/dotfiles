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
      stern
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      k3s
    ]
    ++ lib.optionals (!stdenv.hostPlatform.isLinux) [
      kubectl
    ];
}
