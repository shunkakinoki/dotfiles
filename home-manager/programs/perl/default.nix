{ pkgs, ... }:
{
  home.packages = with pkgs; [
    perl
    perlPackages.PLS
  ];
}
