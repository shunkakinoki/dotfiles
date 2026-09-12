{
  config,
  pkgs,
  ...
}:

let
  installHerdrIntegrations = ./install-integrations.sh;
in
{
  home.file.".config/herdr/config.toml" = {
    source = ./config.toml;
    force = true;
  };
  home.file.".config/herdr/agent-detection/opencode.toml".source = ./agent-detection/opencode.toml;

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
        $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${installHerdrIntegrations}" "${pkgs.llm-agents.herdr}/bin/herdr"
      '';
}
