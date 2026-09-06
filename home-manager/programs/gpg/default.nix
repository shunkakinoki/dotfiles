{
  config,
  lib,
  pkgs,
  isRunner ? false,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  identityKey =
    if config.home.username == "root" then
      "/etc/ssh/ssh_host_ed25519_key"
    else
      "${config.home.homeDirectory}/.ssh/id_ed25519";
in
{
  programs.gpg = {
    enable = true;
    settings.default-key = "shunkakinoki@gmail.com";
  };

  home.activation.importGpgKey = lib.mkIf (!isRunner) (
    config.lib.dag.entryAfter [ "linkGeneration" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../activation/import-gpg-key.sh}" \
        "${config.home.homeDirectory}/dotfiles/named-hosts/galactica/keys/gpg.age" \
        "${identityKey}" \
        "${pkgs.rage}/bin/rage" \
        "${pkgs.gnupg}/bin/gpg" \
        "C2E97FCFF482925D"
    ''
  );

  services.gpg-agent = lib.mkIf isLinux {
    enable = true;
    defaultCacheTtl = lib.mkDefault 2147483647;
    maxCacheTtl = lib.mkDefault 2147483647;
    pinentry.package = lib.mkDefault pkgs.pinentry-curses;
    enableSshSupport = false;
  };

}
