{ config, ... }:
{
  home.file.".codex/config.toml" = {
    source = ./config.toml;
    force = true;
  };
}
