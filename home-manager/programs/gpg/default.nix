{
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isLinux isDarwin;
in
{
  programs.gpg = {
    enable = true;
  };

  services.gpg-agent = lib.mkIf isLinux {
    enable = true;
    defaultCacheTtl = lib.mkDefault 2147483647;
    maxCacheTtl = lib.mkDefault 2147483647;
    pinentry.package = lib.mkDefault pkgs.pinentry-curses;
    enableSshSupport = false;
  };

}
