{
  lib,
  pkgs,
  ...
}:
{
  # Off PATH on purpose: install-npm-globals links ~/.bun/bin/opencode here
  # after every bun install, since bun rewrites that shim to the raw binary.
  home.file.".local/libexec/opencode" = {
    source = lib.getExe (
      pkgs.writeShellApplication {
        name = "opencode";
        text = builtins.readFile ./opencode.sh;
      }
    );
  };

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
