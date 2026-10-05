_: {
  home.file.".pi/agent/models.json" = {
    source = ./models.json;
  };
  home.file.".pi/agent/settings.json" = {
    source = ./settings.json;
  };
  home.file.".pi/agent/keybindings.json" = {
    source = ./keybindings.json;
  };
  home.file.".pi/agent/extensions/moshi-hooks.ts" = {
    source = ../../generated/hooks/moshi/pi/moshi-hooks.ts;
  };
  home.file.".pi/agent/extensions/traces-hooks.ts" = {
    source = ./traces-hooks.ts;
  };
  home.file.".pi/agent/fallback.json" = {
    source = ./fallback.json;
  };
  home.file.".pi/agent/extensions/fallback.ts" = {
    source = ./fallback.ts;
  };
}
