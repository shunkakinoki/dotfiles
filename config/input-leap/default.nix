{ config, pkgs, ... }:
let
  inherit (pkgs) lib;
  inherit (pkgs.stdenv) isDarwin isLinux;
in
{
  # Server config on galactica (macOS)
  home.file."Library/Application Support/InputLeap/InputLeap.conf" = lib.mkIf isDarwin {
    source = ./server.conf;
  };

  # Server config on galactica (XDG fallback)
  xdg.configFile."InputLeap/InputLeap.conf" = lib.mkIf isDarwin {
    source = ./server.conf;
  };
}
