{ config, ... }:
{
  # CCS (Claude Code Switcher) account registry
  # Maps OAuth token files to registered accounts for cliproxy providers
  # Token files are stored separately in ~/.ccs/cliproxy/auth/ (not managed here as they contain secrets)
  home.file.".ccs/cliproxy/accounts.json" = {
    source = config.lib.file.mkOutOfStoreSymlink ./accounts.json;
    force = true;
  };
}
