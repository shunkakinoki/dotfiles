{ config, ... }:
{
  home.file.".config/opencode/opencode.jsonc" = {
    source = ./opencode.jsonc;
    force = true;
  };
}
