{
  config,
  pkgs,
  ...
}:
{
  # Clean up the hydrate.sh output before linkGeneration so it doesn't
  # block the next nix-switch.
  home.activation.cassSourcesCleanup = config.lib.dag.entryBefore [ "linkGeneration" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash -c '
      if [ -f "${config.home.homeDirectory}/.config/cass/sources.toml" ]; then
        rm -f "${config.home.homeDirectory}/.config/cass/sources.toml"
      fi
    '
  '';

  # sources.toml is hydrated at activation so each machine can drop itself from
  # the peer list using its runtime hostname.
  home.activation.hydrateCassSources = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./hydrate.sh}"
  '';
}
