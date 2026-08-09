{
  config,
  pkgs,
  ...
}:
{
  # Hybrid is Cass's upstream default, but it starts semantic refinement even
  # when only the lexical index is ready. Keep interactive search responsive
  # until semantic indexing can complete reliably for this archive.
  home.sessionVariables.CASS_SEARCH_MODE = "lexical";

  # Clean up the hydrate.sh output before checkLinkTargets so it does not
  # block the next nix-switch.
  home.activation.cassSourcesCleanup = config.lib.dag.entryBefore [ "checkLinkTargets" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate-cleanup-sources.sh}" \
      "${config.home.homeDirectory}/.config/cass/sources.toml"
  '';

  # sources.toml is hydrated at activation so each machine can drop itself from
  # the peer list using its runtime hostname.
  home.activation.hydrateCassSources = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./hydrate.sh}"
  '';
}
