_: {
  # Keeps v2 off the 1.x opencode.db so 1.x history is never read or rewritten.
  home.sessionVariables.OPENCODE_DB = "opencode-v2.db";

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
