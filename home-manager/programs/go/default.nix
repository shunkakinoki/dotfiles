{ pkgs, ... }:
{
  home.packages = with pkgs; [
    go
    goimports
    gopls
  ];
}
