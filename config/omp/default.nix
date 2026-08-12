{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Use activation script instead of home.file symlink.
  # Keep the generated config files in dotfiles and leave runtime state untouched.
  home.activation.ompConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${./config.yml}"
  '';

  home.file.".omp/agent/models.yml" = {
    source = ./models.yml;
    force = true;
  };

  home.file.".omp/agent/hooks/post/moshi-hooks.ts" = {
    source = ./moshi-hooks.ts;
    force = true;
  };

  home.file.".omp/agent/fallback.json" = {
    source = ./fallback.json;
    force = true;
  };
  # Kept outside extensions/ so the loader does not pick it up as an extension.
  home.file.".omp/agent/fallback-policy.ts" = {
    source = ../shared/fallback/runtime-fallback.ts;
    force = true;
  };
  home.file.".omp/agent/extensions/fallback.ts" = {
    source = ./fallback.ts;
    force = true;
  };
}
