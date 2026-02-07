{ config, ... }:
{
  home.file."Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json" = {
    source = ./profile.json;
    force = true;
  };
}
