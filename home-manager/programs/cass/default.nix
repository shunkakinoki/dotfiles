{
  config,
  pkgs,
  ...
}:
{
  # sources.toml is hydrated at activation so each machine can drop itself from
  # the peer list using its runtime hostname.
  home.activation.hydrateCassSources = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./hydrate.sh}"
  '';
}
