{
  config,
  pkgs,
  ...
}:
{
  # Keeps v2 off the 1.x opencode.db so 1.x history is never read or rewritten.
  home.sessionVariables.OPENCODE_DB = "opencode-v2.db";

  # The v2 service takes its env from service.json, not the spawning shell.
  # The service also writes its client password there, so merge instead of
  # linking a read-only file; `opencode service set env` would restart it.
  home.activation.opencodeServiceEnv = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${pkgs.jq}/bin:${pkgs.coreutils}/bin:$PATH
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./service-env.sh}
  '';

  home.file.".config/opencode/opencode.jsonc" = {
    source = ./opencode.jsonc;
  };

  home.file.".config/opencode/opencode-fallback.jsonc" = {
    source = ./opencode-fallback.jsonc;
  };

  # OpenCode reports lowercase bash; Claude's Bash matcher is case-sensitive.
  home.file.".config/opencode/hooks.json" = {
    source = ./hooks.json;
  };

  home.file.".config/opencode/tui.json" = {
    source = ./tui.json;
  };

  home.file.".config/opencode/themes/transparent.json" = {
    source = ./themes/transparent.json;
  };

  home.file.".config/opencode/plugins/moshi-hooks.ts" = {
    source = ../../generated/hooks/moshi/opencode/moshi-hooks.ts;
  };

  home.file.".config/opencode/plugins/claude-hooks.ts" = {
    source = ./plugins/claude-hooks.ts;
  };
}
