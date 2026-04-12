{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin;
in
{
  # Install uv global tools from pyproject.toml using home-manager activation
  home.activation.installUvGlobals = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${pkgs.uv}/bin:${pkgs.dasel}/bin:${pkgs.jq}/bin:${pkgs.yq}/bin:$PATH
    ${lib.optionalString (!isDarwin) ''export SYSTEMCTL_BIN="${pkgs.systemd}/bin/systemctl"''}
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./install-uv-globals.sh}"
  '';

  # Run uv globals install after login (Linux only - systemd)
  systemd.user.services = lib.mkIf (!isDarwin) {
    install-uv-globals = {
      Unit = {
        Description = "Install uv global tools";
        After = [ "default.target" ];
      };
      Service = {
        Type = "simple";
        Environment = [
          "PATH=${pkgs.uv}/bin:${pkgs.dasel}/bin:${pkgs.jq}/bin:${pkgs.yq}/bin:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin"
          "HOME=%h"
        ];
        ExecStart = "${pkgs.bash}/bin/bash ${./install-uv-globals.sh}";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };

  # Add uv tools bin to PATH
  home.sessionPath = [
    "$HOME/.local/bin"
  ];
}
