{ pkgs, ... }:
{
  home.file."Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json" = {
    enable = pkgs.stdenv.hostPlatform.isDarwin;
    source = ./profile.json;
    force = true;
  };
}
