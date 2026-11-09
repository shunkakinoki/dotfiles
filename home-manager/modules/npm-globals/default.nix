{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  activationDeps = [
    "linkGeneration"
    "fnmSetup"
  ];
in
{
  # Install npm global packages from package.json using home-manager activation
  # After linkGeneration so the managed opencode wrapper exists to relink, and
  # after fnmSetup because package lifecycle scripts (openclaw preinstall) check
  # the Node version, so the pinned fnm default must exist and win on PATH.
  home.activation.installNpmGlobals = config.lib.dag.entryAfter activationDeps ''
    export PATH=${pkgs.bun}/bin:${pkgs.jq}/bin:${pkgs.curl}/bin:${pkgs.git}/bin:${pkgs.gnutar}/bin:${pkgs.gzip}/bin:${pkgs.xz}/bin:$HOME/.local/bin:${pkgs.nodejs}/bin:$PATH
    export BUN_INSTALL="$HOME/.bun"
    ${lib.optionalString (!isDarwin) ''export SYSTEMCTL_BIN="${config.systemd.user.systemctlPath}"''}
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
          "PATH=${pkgs.bun}/bin:${pkgs.jq}/bin:${pkgs.curl}/bin:${pkgs.git}/bin:${pkgs.gnutar}/bin:${pkgs.gzip}/bin:${pkgs.xz}/bin:%h/.local/bin:${pkgs.nodejs}/bin:${pkgs.findutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin"
          "BUN_INSTALL=%h/.bun"
          "HOME=%h"
          "T3_BOOT_SERVICE_UNIT="
        ];
        ExecStart = "${pkgs.bash}/bin/bash ${./install-npm-globals.sh}";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };

  # Fleet wakes exec `$HOME/.bun/bin/bun` by absolute path, so an unmanaged
  # link there can vanish or drift off the pinned release. `force` replaces the
  # plain files and hand-made relinks hosts already carry at this path.
  home.file.".bun/bin/bun" = {
    source = lib.getExe pkgs.bun;
  };

  home.sessionVariables = {
    BUN_INSTALL = "$HOME/.bun";
  };

  # Add local and bun bins to PATH
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.bun/install/global/node_modules/.bin"
    "$HOME/.bun/bin"
  ];
}
