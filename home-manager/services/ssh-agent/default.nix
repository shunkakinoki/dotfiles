{
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isLinux;
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

        # Always try to load the default key
        if test -f ~/.ssh/id_ed25519
          set -a keys ~/.ssh/id_ed25519
        end

        # Initialize keychain with found keys
        if test (count $keys) -gt 0
          # Use --quiet to suppress most output, --eval to set environment variables
          # --confirm will skip keys that need a passphrase in non-interactive contexts
          # keychain picks its output syntax from $SHELL, which keeps the parent's
          # value (often bash) when fish is started from another shell or a service.
          # keychain 3.0.4 emits universal (-U) variables, which outlive the agent and
          # leave later shells with a stale socket, so scope them to this session.
          set -eU SSH_AUTH_SOCK SSH_AGENT_PID 2>/dev/null
          eval (env SHELL=fish keychain --eval --quiet --confirm $keys 2>/dev/null | string replace -a -- " -U " " -g "; or true)
        end
      end
    ''
  );
}
