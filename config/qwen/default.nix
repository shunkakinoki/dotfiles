{ pkgs, ... }:
{
  home.file.".qwen/settings.json" = {
    source = pkgs.replaceVars ./settings.json {
      moshiHook = "${pkgs.moshi-hook}/bin/moshi-hook";
    };
    force = true;
  };
}
