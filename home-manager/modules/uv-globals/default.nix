{ config, pkgs, ... }:
{
  # Install uv global tools from pyproject.toml using home-manager activation
  home.activation.installUvGlobals = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${pkgs.uv}/bin:${pkgs.dasel}/bin:${pkgs.jq}/bin:$PATH
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./install-uv-globals.sh}
  '';

  # Add uv tools bin to PATH
  home.sessionPath = [
    "$HOME/.local/bin"
  ];
}
