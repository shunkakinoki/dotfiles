{ pkgs, ... }:
{
  home.packages = with pkgs; [
    kotlin
    kotlin-language-server
  ];
}
