{ pkgs, ... }:
{
  home.file.".config/opencode/opencode.jsonc" = {
    source = ./opencode.jsonc;
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
    source = pkgs.replaceVars ./moshi-hooks.ts {
      moshiHook = "${pkgs.moshi-hook}/bin/moshi-hook";
    };
    force = true;
  };
}
