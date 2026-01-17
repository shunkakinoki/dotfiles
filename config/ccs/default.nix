{ config, lib, pkgs, ... }:
let
  dotfilesDir = "${config.home.homeDirectory}/dotfiles";
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
  home.activation.hydrateCcsSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ENV_FILE="${dotfilesDir}/.env"
    TEMPLATE="${dotfilesDir}/config/ccs/agy.settings.template.json"
    OUTPUT="${config.home.homeDirectory}/.ccs/agy.settings.json"

    if [ -f "$ENV_FILE" ] && [ -f "$TEMPLATE" ]; then
      # Source .env to get CLIPROXY_API_KEY
      set -a
      . "$ENV_FILE"
      set +a

      # Substitute placeholder and write output
      if [ -n "$CLIPROXY_API_KEY" ]; then
        ${pkgs.gnused}/bin/sed \
          -e "s|__CLIPROXY_API_KEY__|$CLIPROXY_API_KEY|g" \
          "$TEMPLATE" > "$OUTPUT"
        $VERBOSE_ECHO "Hydrated CCS agy.settings.json with CLIPROXY_API_KEY"
      else
        $VERBOSE_ECHO "Warning: CLIPROXY_API_KEY not set in .env, skipping agy.settings.json hydration"
      fi
    fi
  '';
}
