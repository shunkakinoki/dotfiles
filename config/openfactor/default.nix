{
  config,
  lib,
  pkgs,
  ...
}:
let
  installPath = lib.makeBinPath [
    pkgs.curl
    pkgs.gnutar
    pkgs.gzip
  ];
in
{
  # Hook configuration is owned by each harness, so register after their
  # activation steps have materialized writable host files. The published
  # OpenFactor CLI remains the single adapter/receipt owner.
  home.activation.openfactorHooks =
    config.lib.dag.entryAfter
      [
        "antigravityCliSettings"
        "claudeConfig"
        "codexConfig"
        "copilotConfig"
        "cursorHooks"
        "devinConfig"
        "factorySettings"
        "geminiSettings"
        "grokConfig"
        "installOpenCodePlugins"
        "ompConfig"
      ]
      ''
        export OPENFACTOR_PERL=${pkgs.perl}/bin/perl
        export OPENFACTOR_INSTALL_PATH=${installPath}
        $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./install.sh}"
      '';
}
