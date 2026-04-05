{ config, pkgs, ... }:
{
  # Install uv global tools from pyproject.toml using home-manager activation
  home.activation.installUvGlobals = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    if [ -n "''${INVOCATION_ID:-}" ]; then
      echo "Running inside systemd service, skipping uv globals install"
    else
    export PATH=${pkgs.uv}/bin:${pkgs.dasel}/bin:${pkgs.jq}/bin:$PATH
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./install-uv-globals.sh}
    fi
  '';

  # Add uv tools bin to PATH
  home.sessionPath = [
    "$HOME/.local/bin"
  ];
}
