{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    go
    (lib.lowPrio gotools)
    gopls
  ];
}
