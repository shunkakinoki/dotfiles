{ pkgs, ... }:
{
  xdg.configFile."cass/sources.toml".source = ./sources.toml;
  home.file."Library/Application Support/cass/sources.toml" = {
    enable = pkgs.stdenv.isDarwin;
    source = ./sources.toml;
  };
}
