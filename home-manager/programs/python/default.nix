{ pkgs, ... }:
{
  home.packages = with pkgs; [
    python3
    pyright
  ];

  programs.fish.interactiveShellInit = ''
    fish_add_path -p ~/.local/bin
  '';
}
