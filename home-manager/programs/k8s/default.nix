{ pkgs, ... }:
{
  home.packages = with pkgs; [
    k9s
    kind
    kubeconform
    kubectl
    kubectx
    kubernetes-helm
    kustomize
  ];
}
