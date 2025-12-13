{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
in
{
  # Configure keychain for Linux systems
  # macOS uses built-in keychain via UseKeychain SSH option
  programs.fish.loginShellInit = lib.mkIf isLinux (
    lib.mkAfter ''
      # Initialize keychain for SSH key management
      # This automatically starts ssh-agent and loads SSH keys
      if command -v keychain > /dev/null
        # Load keys that exist
        set -l keys

        # Always try to load the default key (no passphrase)
        if test -f ~/.ssh/id_ed25519
          set -a keys ~/.ssh/id_ed25519
        end

        # Load GitHub key if it exists (may have passphrase)
        if test -f ~/.ssh/id_ed25519_github
          set -a keys ~/.ssh/id_ed25519_github
        end

        # Initialize keychain with found keys
        if test (count $keys) -gt 0
          # Use --quiet to suppress most output, --eval to set environment variables
          # --confirm will skip keys that need a passphrase in non-interactive contexts
          eval (keychain --eval --quiet --confirm $keys ^/dev/null; or true)
        end
      end
    ''
  );
}
