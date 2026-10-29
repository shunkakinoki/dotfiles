{
  config,
  pkgs,
  lib,
  isRunner,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  gpuEnv = "UV_GLOBALS_GPU=${if config.modules.uvGlobals.gpuTools then "1" else "0"}";
in
{
  # The GPU/ML tool environments take 10G+ and are dead weight on CPU-only
  # Linux workers, which run close to their free-disk admission floor.
  options.modules.uvGlobals.gpuTools = lib.mkOption {
    type = lib.types.bool;
    default = isDarwin;
    description = "Install the pyproject.toml [tool.uv-globals] gpu tools; uninstall them when false.";
  };

  config = {
    # Install uv global tools from pyproject.toml using home-manager activation
    home.activation.installUvGlobals = lib.mkIf (!isRunner) (
      config.lib.dag.entryAfter [ "writeBoundary" ] ''
        export PATH=${pkgs.uv}/bin:${pkgs.dasel}/bin:${pkgs.jq}/bin:${pkgs.yq}/bin:$PATH
        ${lib.optionalString (!isDarwin) ''export SYSTEMCTL_BIN="${pkgs.systemd}/bin/systemctl"''}
        export ${gpuEnv}
        $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./install-uv-globals.sh}"
      ''
    );

    # Run uv globals install after login (Linux only - systemd)
    systemd.user.services = lib.mkIf (!isDarwin && !isRunner) {
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
            gpuEnv
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
  };
}
