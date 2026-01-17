{ config, ... }:
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
}
