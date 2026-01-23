{ config, ... }:
{
  home.file.".gemini/settings.json" = {
    source = ./settings.json;
    force = true;
  };
}
