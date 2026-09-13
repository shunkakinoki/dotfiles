{
  config,
  pkgs,
  ...
}:

let
  installHerdrIntegrations = ./install-integrations.sh;
in
{
  # Hooks and services must interrogate the same managed client. An explicit
  # absolute selector prevents PATH precedence from selecting an older global
  # Herdr binary after the package is upgraded.
  home.sessionVariables.HERDR_BIN_PATH = "${pkgs.llm-agents.herdr}/bin/herdr";

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
