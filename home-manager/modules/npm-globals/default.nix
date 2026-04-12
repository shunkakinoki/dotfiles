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
  home.activation.installNpmGlobals = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${pkgs.bun}/bin:${pkgs.jq}/bin:$PATH
    export BUN_INSTALL="$HOME/.bun"
    ${lib.optionalString (!isDarwin) ''export SYSTEMCTL_BIN="${pkgs.systemd}/bin/systemctl"''}
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./install-npm-globals.sh}"
  '';

  # Run npm globals install after login (Linux only - systemd)
  systemd.user.services = lib.mkIf (!isDarwin) {
    install-npm-globals = {
      Unit = {
        Description = "Install npm global packages";
        After = [ "default.target" ];
      };
      Service = {
        Type = "simple";
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
