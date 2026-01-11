{
  config,
  lib,
  pkgs,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  clawdbotDir = "${homeDir}/.config/clawdbot";

  # Script to extract secrets from cliproxyapi auth and .env
  # Uses pkgs.replaceVars to substitute tool paths at build time
  extractSecretsScript = pkgs.replaceVars ./extract-secrets.sh {
    grep = "${pkgs.gnugrep}/bin/grep";
    cut = "${pkgs.coreutils}/bin/cut";
    find = "${pkgs.findutils}/bin/find";
    head = "${pkgs.coreutils}/bin/head";
    jq = "${pkgs.jq}/bin/jq";
    tr = "${pkgs.coreutils}/bin/tr";
  };
in
{
  # Extract secrets from cliproxyapi auth and .env on home-manager activation
  home.activation.clawdbotSecrets = lib.mkIf (lib ? hm && lib.hm ? dag) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.bash}/bin/bash ${extractSecretsScript}
    ''
  );

  programs.clawdbot = {
    # Enable ALL first-party plugins (some are macOS-only)
    firstParty = {
      summarize.enable = true; # Link -> clean text -> summary
      peekaboo.enable = pkgs.stdenv.isDarwin; # macOS screenshots with AI vision (macOS only)
      oracle.enable = true; # Bundle prompts/files for AI queries
      poltergeist.enable = true; # File watcher with auto-rebuild
      sag.enable = true; # ElevenLabs TTS
      camsnap.enable = true; # RTSP/ONVIF camera snapshots
      gogcli.enable = true; # Google CLI (Gmail, Calendar, Drive)
      bird.enable = true; # X/Twitter CLI
      sonoscli.enable = true; # Sonos speaker control
      imsg.enable = pkgs.stdenv.isDarwin; # iMessage/SMS CLI (macOS only)
    };

    # Default settings
    defaults = {
      model = "anthropic/claude-opus-4-5";
      thinkingDefault = "high";
    };

    # Instance configuration
    instances.default = {
      enable = true;

      # Service configuration (launchd for macOS, systemd for Linux)
      launchd.enable = pkgs.stdenv.isDarwin;
      systemd.enable = pkgs.stdenv.isLinux;

      # Anthropic API provider (reads from ~/.config/clawdbot/anthropic-key)
      providers.anthropic = {
        apiKeyFile = "${clawdbotDir}/anthropic-key";
      };

      # Telegram provider (reads from ~/.config/clawdbot/telegram-token)
      providers.telegram = {
        enable = true;
        botTokenFile = "${clawdbotDir}/telegram-token";
        allowFrom = [ 983653361 ];
        groups = {
          "*" = {
            requireMention = true;
          };
        };
      };
    };
  };
}
