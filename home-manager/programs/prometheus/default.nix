{ pkgs, ... }:
{
  home.packages = with pkgs; [
    prom2json
    prometheus
    prometheus-alertmanager
  ];
}
