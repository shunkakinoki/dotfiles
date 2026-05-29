{ lib, pkgs, ... }:
{
  # Handy mutates settings_store.json at runtime (UI changes, API keys, etc.),
  # so we copy via activation instead of symlinking the read-only Nix store.
  # Do NOT commit populated post_process_api_keys to this file.
  home.activation.handyConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${./settings_store.json}"
  '';
}
