{ config, ... }:
{
  home.file.".pi/agent/models.json" = {
    source = config.lib.file.mkOutOfStoreSymlink ./models.json;
    force = true;
  };
  home.file.".pi/agent/settings.json" = {
    source = config.lib.file.mkOutOfStoreSymlink ./settings.json;
    force = true;
  };
  home.file.".pi/agent/keybindings.json" = {
    source = config.lib.file.mkOutOfStoreSymlink ./keybindings.json;
    force = true;
  };
}
