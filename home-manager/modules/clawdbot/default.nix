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

  # Remote gateway URL for non-kyber machines (macOS nodes connect here)
  # Using Tailscale MagicDNS for direct connectivity (bridge is TCP, not HTTP)
  remoteGatewayUrl = "ws://kyber.tail950b36.ts.net:18789";

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

      # Service configuration:
      # - Linux (kyber): systemd runs the gateway daemon
      # - macOS: launchd disabled (remote mode - no local gateway)
      launchd.enable = false; # macOS uses remote mode, no local gateway
      systemd.enable = pkgs.stdenv.isLinux;

      # Platform-specific config overrides
      # NOTE: uses configOverrides because upstream nix-clawdbot doesn't merge `config` into output
      configOverrides =
        # Linux (kyber): Local gateway mode with browser + bridge for nodes
        lib.optionalAttrs pkgs.stdenv.isLinux {
          gateway = {
            mode = "local";
            bind = "lan";
          };
          bridge = {
            enabled = true;
            bind = "lan"; # Allow nodes to connect from LAN/ingress
          };
          browser = {
            enabled = true;
            headless = true;
            executablePath = "${pkgs.chromium}/bin/chromium";
            noSandbox = true; # SUID sandbox requires root-owned binary with mode 4755
          };
        }
        # macOS: Remote mode - connect to Linux gateway as a node
        // lib.optionalAttrs pkgs.stdenv.isDarwin {
          gateway = {
            mode = "remote";
            url = remoteGatewayUrl;
            # Auth token read from file (set via extract-secrets or manually)
            tokenFile = "${clawdbotDir}/gateway-token";
          };
          browser = {
            enabled = true;
            headless = false;
          };
        };

      # Anthropic API provider (reads from ~/.config/clawdbot/anthropic-key)
      # Only needed on the gateway (Linux), but harmless to keep on nodes
      providers.anthropic = {
        apiKeyFile = "${clawdbotDir}/anthropic-key";
      };

      # Telegram provider - Linux gateway only (reads from ~/.config/clawdbot/telegram-token)
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
