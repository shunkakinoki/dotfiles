{
  config,
  pkgs,
  ...
}:

{
  home.file.".config/herdr/config.toml" = {
    source = ./config.toml;
    force = true;
  };

  # Install Herdr's native integrations only after both harness configuration
  # owners have materialized their live files. The installer only updates hook
  # and plugin registration; it does not restart a running harness.
  home.activation.installHerdrIntegrations =
    config.lib.dag.entryAfter
      [
        "codexConfig"
        "installOpenCodePlugins"
      ]
      ''
        $DRY_RUN_CMD ${pkgs.llm-agents.herdr}/bin/herdr integration install codex
        $DRY_RUN_CMD ${pkgs.llm-agents.herdr}/bin/herdr integration install opencode
      '';
}
