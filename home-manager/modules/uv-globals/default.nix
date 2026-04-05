{ config, pkgs, ... }:
{
  # Install uv global tools from pyproject.toml using home-manager activation
  home.activation.installUvGlobals = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    if [ "$(${pkgs.systemd}/bin/systemctl is-system-running 2>/dev/null)" = "starting" ]; then
      echo "System is booting, skipping uv globals install"
    else
    export PATH=${pkgs.uv}/bin:${pkgs.dasel}/bin:${pkgs.jq}/bin:$PATH
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./install-uv-globals.sh}
    fi
  '';

  # Run uv globals install after login
  systemd.user.services.install-uv-globals = {
    Unit = {
      Description = "Install uv global tools";
      After = [ "default.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${pkgs.uv}/bin:${pkgs.dasel}/bin:${pkgs.jq}/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin"
        "HOME=%h"
      ];
      ExecStart = "${pkgs.bash}/bin/bash ${./install-uv-globals.sh}";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Add uv tools bin to PATH
  home.sessionPath = [
    "$HOME/.local/bin"
  ];
}
