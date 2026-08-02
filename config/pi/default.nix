{ pkgs, ... }:
{
  home.file.".pi/agent/models.json" = {
    source = ./models.json;
    force = true;
  };
  home.file.".pi/agent/settings.json" = {
    source = ./settings.json;
    force = true;
  };
  home.file.".pi/agent/keybindings.json" = {
    source = ./keybindings.json;
    force = true;
  };
  home.file.".pi/agent/extensions/moshi-hooks.ts" = {
    source = pkgs.replaceVars ./moshi-hooks.ts {
      moshiHook = "${pkgs.moshi-hook}/bin/moshi-hook";
    };
    force = true;
  };
}
