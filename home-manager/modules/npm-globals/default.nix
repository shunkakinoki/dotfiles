{ config, pkgs, ... }:
{
  # Install npm global packages from package.json using home-manager activation
  home.activation.installNpmGlobals = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    if [ "$(${pkgs.systemd}/bin/systemctl is-system-running 2>/dev/null)" = "starting" ]; then
      echo "System is booting, skipping npm globals install"
    else
    export PATH=${pkgs.bun}/bin:${pkgs.jq}/bin:$PATH
    export BUN_INSTALL="$HOME/.bun"
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./install-npm-globals.sh}
    fi
  '';

  home.sessionVariables = {
    BUN_INSTALL = "$HOME/.bun";
  };

  # Add local and bun bins to PATH
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.bun/bin"
  ];
}
