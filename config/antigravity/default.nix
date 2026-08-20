{
  config,
  pkgs,
  ...
}:
{
  # Antigravity CLI persists interactive preferences in this file. Merge the
  # model default instead of symlinking the whole file into the Nix store.
  home.activation.antigravityCliSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" \
      "${./settings.json}" \
      "${pkgs.jq}/bin/jq"
  '';
}
