{ pkgs, ... }:
{
  home.packages = with pkgs; [ pkgs.lazydocker ];
}
