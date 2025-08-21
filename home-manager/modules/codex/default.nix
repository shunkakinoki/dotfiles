{ config, ... }:
{
  home.file.".codex/config.toml" = {
    source = config.lib.file.mkOutOfStoreSymlink ./config.toml;
  };
}
