{ pkgs, ... }:
{
  home.packages = with pkgs; [
    node
    nodePackages.typescript-language-server
  ];
}
