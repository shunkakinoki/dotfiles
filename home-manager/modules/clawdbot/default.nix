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
      oracle.enable = pkgs.stdenv.isDarwin; # Bundle prompts/files for AI queries (macOS only)
      poltergeist.enable = pkgs.stdenv.isDarwin; # File watcher with auto-rebuild (macOS only)
      sag.enable = pkgs.stdenv.isDarwin; # ElevenLabs TTS (macOS only)
      camsnap.enable = pkgs.stdenv.isDarwin; # RTSP/ONVIF camera snapshots (macOS only)
      gogcli.enable = pkgs.stdenv.isDarwin; # Google CLI (Gmail, Calendar, Drive) (macOS only)
      bird.enable = pkgs.stdenv.isDarwin; # X/Twitter CLI (macOS only)
      sonoscli.enable = pkgs.stdenv.isDarwin; # Sonos speaker control (macOS only)
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

      # Telegram provider - Linux only (reads from ~/.config/clawdbot/telegram-token)
      providers.telegram = {
        enable = pkgs.stdenv.isLinux;
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
