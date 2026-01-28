{ config, ... }:
{
  home.file.".config/crush/crush.json" = {
    source = ./crush.json;
    force = true;
  };
}
