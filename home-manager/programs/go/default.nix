{ pkgs, ... }:
{
  programs.fish.interactiveShellInit = ''
    fish_add_path -p ~/go/bin
  '';
  programs.go = {
    enable = true;
    package = pkgs.go_1_23;
    goPath = "go";
    goBin = "go/bin";
  };
}
