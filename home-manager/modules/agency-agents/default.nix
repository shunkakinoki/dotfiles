{
  config,
  pkgs,
  lib,
  isRunner,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  # Tools needed by install-agency-agents.sh and upstream scripts/install.sh
  # (git sync + find/awk/sed/grep used by convert/install helpers).
  agencyPath = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.findutils
    pkgs.gawk
    pkgs.git
    pkgs.gnugrep
    pkgs.gnused
    pkgs.python3
  ];
in
{
  # Clone/update agency-agents roster and install into local agent tools.
  home.activation.installAgencyAgents = lib.mkIf (!isRunner) (
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      export PATH=${agencyPath}:$PATH
      ${lib.optionalString (!isDarwin) ''export SYSTEMCTL_BIN="${pkgs.systemd}/bin/systemctl"''}
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./install-agency-agents.sh}"
    ''
  );

  # Re-run after login on Linux (same pattern as uv/npm/cargo-globals).
  systemd.user.services = lib.mkIf (!isDarwin && !isRunner) {
    install-agency-agents = {
      Unit = {
        Description = "Install agency-agents roster into local agent tools";
        After = [ "default.target" ];
      };
      Service = {
        Type = "oneshot";
        Environment = [
          "PATH=${agencyPath}"
          "HOME=%h"
        ];
        ExecStart = "${pkgs.bash}/bin/bash ${./install-agency-agents.sh}";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
