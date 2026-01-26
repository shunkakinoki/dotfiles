{
  config,
  lib,
  pkgs,
  ...
}:
let
  dotfilesDir = "${config.home.homeDirectory}/dotfiles";

  # Hydration script for CCS provider settings
  hydrateScript = pkgs.replaceVars ./hydrate.sh {
    sed = "${pkgs.gnused}/bin/sed";
  };
in
{
  # CCS (Claude Code Switcher) account registry
  # Maps OAuth token files to registered accounts for cliproxy providers
  # Token files are stored separately in ~/.ccs/cliproxy/auth/ (not managed here as they contain secrets)
  # Note: accounts.json is hydrated from template only if missing (preserves runtime state like lastUsedAt)

  # Hydrate CCS settings templates with secrets from .env
  # ANTHROPIC_AUTH_TOKEN is substituted from CLIPROXY_API_KEY at activation time
  # Processes all *.settings.template.json files in config/ccs/
  home.activation.hydrateCcsSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash ${hydrateScript} || true
  '';
}
