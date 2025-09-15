{ pkgs, ... }:
{
  home.packages = with pkgs; [
    go
  ];
  programs.fish.interactiveShellInit = ''
    fish_add_path -p ~/go/bin
  '';
  programs.go = {
    enable = true;
    goPath = "go";
    goBin = "go/bin";
  };
}
