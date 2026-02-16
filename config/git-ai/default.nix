{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.activation.gitAiConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ~/.git-ai
    GIT_PATH=$(${pkgs.which}/bin/which git 2>/dev/null || echo "${pkgs.git}/bin/git")
    $DRY_RUN_CMD ${pkgs.jq}/bin/jq --arg gp "$GIT_PATH" '. + {git_path: $gp}' ${./config.json} > ~/.git-ai/config.json
    $DRY_RUN_CMD chmod 600 ~/.git-ai/config.json
  '';
}
