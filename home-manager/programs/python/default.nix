{ pkgs, ... }:
{
  programs.fish.interactiveShellInit = ''
    fish_add_path -p ~/.local/bin
  '';
}
