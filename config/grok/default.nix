{ lib, pkgs, ... }:
{
  # Use activation script instead of a home.file symlink.
  # Grok performs atomic writes to config.toml that break symlinks, so force-copy on each switch.
  #
  # The activation also installs a Claude Code-format plugin that wires the shared security
  # hooks. Grok has no user-scoped ~/.grok/hooks/ directory (native hooks are project-scoped
  # under .grok/hooks/ and trust-gated), but it loads user plugins from ~/.grok/plugins/, and
  # plugins provide hooks via hooks/hooks.json.
  home.activation.grokConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${./config.toml}" "${./plugin}"
  '';
}
