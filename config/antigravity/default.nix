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
      "${./hooks.json}" \
      "${pkgs.jq}/bin/jq"
  '';

  # Install Traces' repository-local Git dispatchers before each CLI session;
  # reporting itself remains owned by the official hook in hooks.json.
  home.file.".local/bin/agy" = {
    source = ./agy.sh;
    executable = true;
  };
  home.file.".local/libexec/antigravity-cli/agy".source =
    "${pkgs.llm-agents.antigravity-cli}/bin/agy";
}
