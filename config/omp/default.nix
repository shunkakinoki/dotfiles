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
    source = ../../generated/hooks/moshi/omp/moshi-hooks.ts;
    force = true;
  };
}
