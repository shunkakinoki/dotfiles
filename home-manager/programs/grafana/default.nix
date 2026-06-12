{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gcx
    grafana-alloy
    grafana-loki
  ];
}
