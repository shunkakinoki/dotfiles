{ config, ... }:
{
  home.file.".hammerspoon/init.lua" = {
    source = ./init.lua;
    force = true;
  };
}
