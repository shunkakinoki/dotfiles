{ pkgs, ... }:
{
  home.packages = with pkgs; [
    rustup
  ];

  home.file.".cargo/config.toml".source = ./cargo.toml;
}
