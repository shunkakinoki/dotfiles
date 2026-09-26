{
  config,
  lib,
  pkgs,
  ...
}:
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
        PATH="${
          lib.makeBinPath [
            pkgs.curl
            pkgs.gnutar
            pkgs.gzip
          ]
        }:$PATH" $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./install.sh}"
      '';
}
