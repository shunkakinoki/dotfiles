{ pkgs, ... }:

{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # disable fish greeting
      set fish_greeting
    '';
    shellAliases = {
      ls = "ls -G";
    };
  };
}