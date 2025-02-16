{ pkgs, ... }:

{
  programs.fish.interactiveShellInit = ''
    fish_add_path -p ~/Go/bin
  '';
  programs.fish = {
    enable = true;
    shellAliases = {
      ls = "ls -G";
    };
  };
}