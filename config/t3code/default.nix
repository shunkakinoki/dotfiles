{
  config,
  pkgs,
  ...
}:
let
  activateSettings = ./activate-settings.sh;
  activateClientSettings = ./activate-client-settings.sh;
  stateDir = "${config.home.homeDirectory}/.t3/userdata";
in
{
  # T3 Code owns ~/.t3/userdata/settings.json and rewrites it as provider state
  # changes, so merge the managed CLIProxy instances instead of replacing the
  # file. The CLIProxy credential is injected at activation time from the shared
  # dotenv (see activate-settings.sh); the template only carries a placeholder.
  home.activation.t3codeSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${activateSettings}" \
      "${./server-settings.json}" \
      "${pkgs.jq}/bin/jq" \
      "${config.home.homeDirectory}/dotfiles/.env" \
      "${stateDir}" \
      "${./codex-home/config.toml}"
  '';

  # Favorites and model visibility are device-local; T3 rewrites this file too.
  home.activation.t3codeClientSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${activateClientSettings}" \
      "${./client-settings.json}" \
      "${pkgs.jq}/bin/jq" \
      "${stateDir}"
  '';
}
