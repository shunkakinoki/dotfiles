{ pkgs, ... }:
{
  home.packages = with pkgs; [
    grafana-alloy
    grafana-loki
  ];
}
