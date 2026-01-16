{ config, ... }:
{
  home.file.".config/opencode/opencode.jsonc" = {
    source = config.lib.file.mkOutOfStoreSymlink ./opencode.jsonc;
    force = true;
  };
}
