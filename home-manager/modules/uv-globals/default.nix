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
    ${lib.optionalString (!isDarwin) ''
      if [ "$(${pkgs.systemd}/bin/systemctl is-system-running 2>/dev/null)" = "starting" ]; then
        echo "System is booting, skipping uv globals install"
        exit 0
      fi
    ''}
    export PATH=${pkgs.uv}/bin:${pkgs.dasel}/bin:${pkgs.jq}/bin:${pkgs.yq}/bin:$PATH
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./install-uv-globals.sh}
  '';

  # Run uv globals install after login (Linux only - systemd)
  systemd.user.services = lib.mkIf (!isDarwin) {
    install-uv-globals = {
      Unit = {
        Description = "Install uv global tools";
        After = [ "default.target" ];
      };
      Service = {
        Type = "oneshot";
        Environment = [
          "PATH=${pkgs.uv}/bin:${pkgs.dasel}/bin:${pkgs.jq}/bin:${pkgs.yq}/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin"
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
