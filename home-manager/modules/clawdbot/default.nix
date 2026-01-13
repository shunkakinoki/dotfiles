{
  config,
  lib,
  pkgs,
  ...
}:
let
  env = import ../../../lib/env.nix;
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
# Disable clawdbot entirely in CI builds
lib.mkIf (!env.isCI) {
  # Force overwrite clawdbot.json to prevent home-manager switch failures
  # when the file already exists (e.g., modified by clawdbot at runtime)
  home.file.".clawdbot/clawdbot.json".force = true;

  # Prevent home-manager from auto-restarting clawdbot during activation
  # Restart only happens via explicit `make switch` (which runs systemctl-clawdbot)
  systemd.user.services.clawdbot-gateway = lib.mkIf pkgs.stdenv.isLinux {
    Unit.X-RestartIfChanged = "false";
  };

  # Extract secrets from cliproxyapi auth and .env on home-manager activation
  home.activation.clawdbotSecrets = lib.mkIf (lib ? hm && lib.hm ? dag) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.bash}/bin/bash ${extractSecretsScript}
    ''
  );

  programs.clawdbot = {
    # First-party plugins (all macOS-only)
    firstParty = {
      summarize.enable = pkgs.stdenv.isDarwin; # Link -> clean text -> summary (macOS only)
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

      # Browser configuration (headless on Linux, GUI on macOS)
      # Gateway binds to LAN on Linux for k8s ingress access
      # NOTE: uses configOverrides because upstream nix-clawdbot doesn't merge `config` into output
      configOverrides = {
        browser = {
          enabled = true;
          headless = pkgs.stdenv.isLinux;
        }
        // lib.optionalAttrs pkgs.stdenv.isLinux {
          executablePath = "${pkgs.chromium}/bin/chromium";
          noSandbox = true; # SUID sandbox requires root-owned binary with mode 4755
        };
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        gateway = {
          bind = "lan";
        };
      };

      # Anthropic API provider (reads from ~/.config/clawdbot/anthropic-key)
      providers.anthropic = {
        apiKeyFile = "${clawdbotDir}/anthropic-key";
      };

      # Telegram provider - Linux only (reads from ~/.config/clawdbot/telegram-token)
      providers.telegram = {
        enable = pkgs.stdenv.isLinux;
        botTokenFile = "${clawdbotDir}/telegram-token";
        allowFrom = [
          983653361
          2104262990
        ];
        groups = {
          "*" = {
            requireMention = false;
          };
        };
      };

      # # iMessage provider - macOS only (reads messages from anyone)
      # providers.imessage = {
      #   enable = pkgs.stdenv.isDarwin;
      # };
    };
  };
}
