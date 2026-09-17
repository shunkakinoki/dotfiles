{
  config,
  pkgs,
  ...
}:
{
  # Hook configuration is owned by each harness, so register after their
  # activation steps have materialized writable host files. The OpenFactor CLI
  # remains the single adapter/receipt owner.
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
        $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./install.sh}"
      '';
}
