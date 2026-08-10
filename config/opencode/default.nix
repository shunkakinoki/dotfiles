{
  config,
  pkgs,
  ...
}:
{
  home.file.".config/opencode/opencode.jsonc" = {
    source = ./opencode.jsonc;
    force = true;
  };

  home.file.".config/opencode/opencode-fallback.jsonc" = {
    source = ./opencode-fallback.jsonc;
    force = true;
  };

  home.file.".config/opencode/tui.json" = {
    source = ./tui.json;
    force = true;
  };

  home.file.".config/opencode/themes/transparent.json" = {
    source = ./themes/transparent.json;
    force = true;
  };

  home.file.".config/opencode/plugins/moshi-hooks.ts" = {
    source = ./moshi-hooks.ts;
    force = true;
  };

  home.activation.installOpenCodePlugins = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${pkgs.opencode}/bin/opencode" "${pkgs.jq}/bin/jq"
  '';
}
