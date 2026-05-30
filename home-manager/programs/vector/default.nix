{ pkgs, ... }:
{
  home.packages = with pkgs; [
    vector
  ];
}
