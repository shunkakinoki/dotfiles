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
    pinentryPackage = pkgs.pinentry-curses;
    enableSshSupport = false;
  };

  # macOS: home-manager services.gpg-agent is Linux-only;
  # configure via launchd-managed gpg-agent.conf directly.
  home.file.".gnupg/gpg-agent.conf" = lib.mkIf isDarwin {
    text = ''
      pinentry-program ${lib.getExe pkgs.pinentry_mac}
      allow-loopback-pinentry
      default-cache-ttl 2147483647
      max-cache-ttl 2147483647
    '';
  };
}
