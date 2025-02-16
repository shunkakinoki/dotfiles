{ pkgs, ... }:

{
  programs.fish = {
    enable = true;
    shellAliases = {
      ls = "ls -G";
    };
  };
}