{ pkgs, ... }:
{
  home.packages = with pkgs; [
    dockerfile-language-server
  ];
}
