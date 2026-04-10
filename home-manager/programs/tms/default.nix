{ pkgs, ... }:
{
  home.packages = [
    pkgs.tmux-sessionizer
  ];

  xdg.configFile."tms/config.toml".source = ./config.toml;
}
