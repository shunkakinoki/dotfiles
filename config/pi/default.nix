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
}
