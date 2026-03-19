{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nodePackages.intelephense
    php
  ];
}
