{
  config,
  lib,
  pkgs,
  ...
}:
let
  caamClaudeSnapshot = pkgs.writeShellScriptBin "caam-claude-snapshot" (
    builtins.readFile ./hooks/caam-snapshot.sh
  );
  mergeMoshiHooks = import ../shared/merge-moshi-hooks.nix { inherit pkgs; };
  mergeOrchestrationHooks = ../shared/merge-orchestration-hooks.sh;
  settings =
    mergeMoshiHooks "claude-settings.json" ./settings.json
      ../../generated/hooks/moshi/claude/settings.json;
in
{
  # CAAM isolates HOME for each profile, so hooks invoked by a CAAM-launched
  # Claude session must resolve from PATH rather than ~/.claude/hooks.
  home.packages = [ caamClaudeSnapshot ];

  # Use activation script for settings.json instead of symlink
  # git-ai install-hooks needs write access, which breaks with Nix store symlinks
  home.activation.claudeConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${settings}"
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${mergeOrchestrationHooks}" \
      claude \
      "$HOME/.claude/settings.json" \
      "${pkgs.jq}/bin/jq"
  '';

  home.file.".claude/hooks/auto-switch.sh" = {
    source = ./hooks/auto-switch.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/hooks/pushover.sh" = {
    source = ./hooks/pushover.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/hooks/notify.sh" = {
    source = ./hooks/notify.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/hooks/security.sh" = {
    source = ./hooks/security.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/hooks/statusline.sh" = {
    source = ./hooks/statusline.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/hooks/atuin-history.sh" = {
    source = ./hooks/atuin-history.sh;
    executable = true;
    force = true;
  };
}
