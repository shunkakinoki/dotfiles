{
  config,
  pkgs,
  ...
}:
let
  activate = ./activate.sh;
in
{
  # Devin owns the rest of config.json (model, theme, and session preferences),
  # so activation replaces only the declarative hooks key and preserves all
  # other user settings.
  home.activation.devinConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${activate}" \
      "${./hooks.v1.json}" \
      "${pkgs.jq}/bin/jq"
  '';

  home.file.".config/devin/hooks/notify.sh" = {
    source = ./hooks/notify.sh;
    executable = true;
    force = true;
  };

  home.file.".config/devin/hooks/pushover.sh" = {
    source = ./hooks/pushover.sh;
    executable = true;
    force = true;
  };

  home.file.".config/devin/hooks/atuin-history.sh" = {
    source = ./hooks/atuin-history.sh;
    executable = true;
    force = true;
  };
}
