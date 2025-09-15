{ pkgs, ... }:
{
  home.packages = with pkgs; [
    go
  ];

  programs.fish.interactiveShellInit = ''
    fish_add_path -p ~/go/bin
  '';
  programs.go = {
    env = {
      GOBIN = "$HOME/go/bin";
      GOPATH = "$HOME/go";
    };
  };
}
