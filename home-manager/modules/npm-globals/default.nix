{ config, pkgs, ... }:
{
  # Install npm global packages from package.json using home-manager activation
  home.activation.installNpmGlobals = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${pkgs.bun}/bin:${pkgs.jq}/bin:$PATH
    export BUN_INSTALL="$HOME/.bun"
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./install-npm-globals.sh}
  '';

  # Add local and bun bins to PATH
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.bun/bin"
  ];
}
