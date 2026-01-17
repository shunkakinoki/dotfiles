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
  # Note: Using mkOutOfStoreSymlink with absolute path so CCS can write to the file (updates lastUsedAt)
  home.file.".ccs/cliproxy/accounts.json" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/config/ccs/accounts.json";
    force = true;
  };

  # Hydrate CCS settings templates with secrets from .env
  # ANTHROPIC_AUTH_TOKEN is substituted from CLIPROXY_API_KEY at activation time
  # Processes all *.settings.template.json files in config/ccs/
  home.activation.hydrateCcsSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash ${hydrateScript} || true
  '';
}
