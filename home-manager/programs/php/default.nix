{ pkgs, ... }:
{
  home.packages = with pkgs; [
    intelephense
    php
  ];
}
