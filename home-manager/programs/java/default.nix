{ pkgs, ... }:
{
  home.packages = with pkgs; [
    jdk21
    jdt-language-server
  ];
}
