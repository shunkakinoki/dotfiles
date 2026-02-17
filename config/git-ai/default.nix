{ config, pkgs, ... }:
let
  baseConfig = builtins.fromJSON (builtins.readFile ./config.json);
  hydratedConfig = baseConfig // {
    git_path = "${pkgs.git}/bin/git";
  };
in
{
  home.file.".git-ai/config.json" = {
    text = builtins.toJSON hydratedConfig;
    force = true;
  };
}
