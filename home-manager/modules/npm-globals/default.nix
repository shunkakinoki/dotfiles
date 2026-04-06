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
  # Install npm global packages from package.json using home-manager activation
  home.activation.installNpmGlobals = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${lib.optionalString (!isDarwin) ''
      if [ "$(${pkgs.systemd}/bin/systemctl is-system-running 2>/dev/null)" = "starting" ]; then
        echo "System is booting, skipping npm globals install"
        exit 0
      fi
    ''}
    export PATH=${pkgs.bun}/bin:${pkgs.jq}/bin:$PATH
    export BUN_INSTALL="$HOME/.bun"
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./install-npm-globals.sh}
  '';

  # Run npm globals install after login (Linux only - systemd)
  systemd.user.services = lib.mkIf (!isDarwin) {
    install-npm-globals = {
      Unit = {
        Description = "Install npm global packages";
        After = [ "default.target" ];
      };
      Service = {
        Type = "oneshot";
        Environment = [
          "PATH=${pkgs.bun}/bin:${pkgs.jq}/bin:${pkgs.findutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin"
          "BUN_INSTALL=%h/.bun"
          "HOME=%h"
        ];
        ExecStart = "${pkgs.bash}/bin/bash ${./install-npm-globals.sh}";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };

  home.sessionVariables = {
    BUN_INSTALL = "$HOME/.bun";
  };

  # Add local and bun bins to PATH
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.bun/bin"
  ];
}
