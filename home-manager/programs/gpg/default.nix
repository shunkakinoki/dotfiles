{
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
in
{
  programs.gpg = {
    enable = true;
  };

  services.gpg-agent = lib.mkIf isLinux {
    enable = true;
    defaultCacheTtl = 2147483647;
    maxCacheTtl = 2147483647;
    pinentry.package = lib.mkDefault pkgs.pinentry-curses;
    enableSshSupport = false;
  };

}
