_: {
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
    source = ./moshi-hooks.ts;
    force = true;
  };
  home.file.".pi/agent/fallback.json" = {
    source = ./fallback.json;
    force = true;
  };
  # Kept outside extensions/ so the loader does not pick it up as an extension.
  home.file.".pi/agent/fallback-policy.ts" = {
    source = ../shared/fallback/runtime-fallback.ts;
    force = true;
  };
  home.file.".pi/agent/extensions/fallback.ts" = {
    source = ./fallback.ts;
    force = true;
  };
}
