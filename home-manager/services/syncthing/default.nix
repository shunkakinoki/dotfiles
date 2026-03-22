{ pkgs, lib, ... }:
{
  services.syncthing = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
  };
}
