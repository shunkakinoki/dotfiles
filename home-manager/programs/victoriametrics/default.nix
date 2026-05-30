{ pkgs, ... }:
{
  home.packages = with pkgs; [
    victorialogs
    victoriametrics
    victoriatraces
  ];
}
