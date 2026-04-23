{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nixd
    nixfmt-rfc-style
  ];

}
