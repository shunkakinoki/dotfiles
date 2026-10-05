{
  config,
  pkgs,
  ...
}:
{
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

  home.activation.installOpenCodePlugins = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${pkgs.opencode}/bin/opencode" "${pkgs.jq}/bin/jq" "${pkgs.bun}/bin/bun"
  '';
}
