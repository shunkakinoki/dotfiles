{ config, ... }:
{
  home.file.".config/direnv/direnvrc" = {
    source = ./direnvrc;
    force = true;
  };
}
