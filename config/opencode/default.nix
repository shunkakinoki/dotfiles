{ config, ... }:
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
}
