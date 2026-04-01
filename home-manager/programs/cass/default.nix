{ lib, pkgs, ... }:
{
  xdg.configFile."cass/sources.toml".source = ./sources.toml;
  home.file."Library/Application Support/cass/sources.toml" = lib.mkIf pkgs.stdenv.isDarwin {
    source = ./sources.toml;
  };
}
