{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  inherit (inputs) env host;
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
  # Only applies on kyber where the gateway runs
  systemd.user.services.clawdbot-gateway = lib.mkIf host.isKyber {
    Unit.X-RestartIfChanged = "false";
  };

  # Extract secrets from cliproxyapi auth and .env on home-manager activation
  home.activation.clawdbotSecrets = lib.mkIf (lib ? hm && lib.hm ? dag) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.bash}/bin/bash ${extractSecretsScript}
    ''
  );

  # Inject cliproxy API key into clawdbot.json (apiKeyFile not supported upstream)
  home.activation.clawdbotCliproxyKey = lib.mkIf (lib ? hm && lib.hm ? dag && host.isKyber) (
    lib.hm.dag.entryAfter [ "clawdbotSecrets" "clawdbotConfigFiles" ] ''
      KEY_FILE="${clawdbotDir}/cliproxy-key"
      CONFIG_FILE="${homeDir}/.clawdbot/clawdbot.json"
      if [ -f "$KEY_FILE" ] && [ -f "$CONFIG_FILE" ]; then
        KEY=$(${pkgs.coreutils}/bin/cat "$KEY_FILE" | ${pkgs.coreutils}/bin/tr -d '\n')
        # Inject apiKey into models.providers.cliproxy
        ${pkgs.jq}/bin/jq --arg key "$KEY" \
          '.models.providers.cliproxy.apiKey = $key' \
          "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && \
          ${pkgs.coreutils}/bin/mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "Injected cliproxy API key into clawdbot config"
      fi
    ''
  );

  # Inject gateway token into clawdbot.json for remote mode (tokenFile not supported upstream)
  home.activation.clawdbotRemoteToken = lib.mkIf (lib ? hm && lib.hm ? dag && !host.isKyber) (
    lib.hm.dag.entryAfter [ "clawdbotSecrets" "clawdbotConfigFiles" ] ''
      TOKEN_FILE="${clawdbotDir}/gateway-token"
      CONFIG_FILE="${homeDir}/.clawdbot/clawdbot.json"
      if [ -f "$TOKEN_FILE" ] && [ -f "$CONFIG_FILE" ]; then
        TOKEN=$(${pkgs.coreutils}/bin/cat "$TOKEN_FILE" | ${pkgs.coreutils}/bin/tr -d '\n')
        # Inject token into gateway.remote.token and remove tokenFile
        ${pkgs.jq}/bin/jq --arg token "$TOKEN" \
          '.gateway.remote.token = $token | del(.gateway.remote.tokenFile)' \
          "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && \
          ${pkgs.coreutils}/bin/mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "Injected gateway token into clawdbot config"
      fi
    ''
  );

  # Clean stale port-guard entries on activation (macOS remote mode only)
  # The Clawdbot.app has a bug where dead SSH tunnel PIDs remain in port-guard.json,
  # preventing new tunnels from being created. This cleans up stale entries.
  home.activation.clawdbotCleanPortGuard = lib.mkIf (lib ? hm && lib.hm ? dag && pkgs.stdenv.isDarwin && !host.isKyber) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      PORT_GUARD="${homeDir}/Library/Application Support/Clawdbot/port-guard.json"
      if [ -f "$PORT_GUARD" ]; then
        # Filter out entries for port 18789 (gateway) - our launchd tunnel handles this
        ${pkgs.jq}/bin/jq '[.[] | select(.port != 18789)]' "$PORT_GUARD" > "$PORT_GUARD.tmp" && \
          ${pkgs.coreutils}/bin/mv "$PORT_GUARD.tmp" "$PORT_GUARD"
        echo "Cleaned stale gateway entries from port-guard.json"
      fi
    ''
  );

  # Auto-start Clawdbot.app on login (galactica only)
  # App is installed to /Applications/Nix Apps/ via nix-darwin
  launchd.agents.clawdbot-app = lib.mkIf (pkgs.stdenv.isDarwin && host.isGalactica) {
    enable = true;
    config = {
      Label = "com.clawdbot.app";
      ProgramArguments = [
        "/Applications/Clawdbot.app/Contents/MacOS/Clawdbot"
      ];
      RunAtLoad = true;
      KeepAlive = false;
      StandardOutPath = "/tmp/clawdbot-app.log";
      StandardErrorPath = "/tmp/clawdbot-app.error.log";
    };
  };

  # SSH tunnel to kyber gateway for remote mode (non-kyber macOS only)
  # The Clawdbot.app has a bug where it doesn't reliably create the gateway tunnel,
  # so we maintain a persistent SSH tunnel via launchd as a workaround.
  launchd.agents.clawdbot-tunnel = lib.mkIf (pkgs.stdenv.isDarwin && !host.isKyber) {
    enable = true;
    config = {
      Label = "com.clawdbot.tunnel";
      ProgramArguments = [
        "/usr/bin/ssh"
        "-N"
        "-o"
        "BatchMode=yes"
        "-o"
        "ExitOnForwardFailure=yes"
        "-o"
        "ServerAliveInterval=15"
        "-o"
        "ServerAliveCountMax=3"
        "-L"
        "18789:127.0.0.1:18789"
        "-i"
        "${homeDir}/.ssh/id_ed25519"
        "ubuntu@kyber.tail950b36.ts.net"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardErrorPath = "/tmp/clawdbot-tunnel.err.log";
    };
  };

  programs.clawdbot = {
    # App installed via nix-darwin to /Applications/Nix Apps/
    installApp = false;
    appPackage = null;

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
      # - Kyber only: systemd runs the gateway daemon
      # - All other hosts (macOS + non-kyber Linux): no local gateway
      launchd.enable = false; # Remote mode, no local gateway
      systemd.enable = host.isKyber; # Only kyber runs the gateway

      # Platform-specific config overrides
      # NOTE: uses configOverrides because upstream nix-clawdbot doesn't merge `config` into output
      configOverrides =
        # Kyber only: Local gateway mode with browser + bridge for nodes
        lib.optionalAttrs host.isKyber {
          gateway = {
            mode = "local";
            bind = "lan";
            auth = {
              tokenFile = "${clawdbotDir}/gateway-token";
            };
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
          # Route through cliproxyapi for access to all model providers
          # cliproxyapi runs locally on port 8317 with OpenAI-compatible API
          models = {
            mode = "merge";
            providers = {
              cliproxy = {
                baseUrl = "http://localhost:8317/v1";
                apiKeyFile = "${clawdbotDir}/cliproxy-key";
                api = "openai-completions";
                models =
                  let
                    # Helper to create model entries with required fields
                    mkModel =
                      {
                        id,
                        name,
                        reasoning ? false,
                        contextWindow ? 200000,
                        maxTokens ? 32000,
                      }:
                      {
                        inherit
                          id
                          name
                          reasoning
                          contextWindow
                          maxTokens
                          ;
                        input = [ "text" ];
                        cost = {
                          input = 0;
                          output = 0;
                          cacheRead = 0;
                          cacheWrite = 0;
                        };
                      };
                  in
                  [
                    # Anthropic models
                    (mkModel {
                      id = "claude-opus-4-5-20251101";
                      name = "Claude Opus 4.5";
                    })
                    (mkModel {
                      id = "claude-opus-4-5-thinking";
                      name = "Claude Opus 4.5 Thinking";
                      reasoning = true;
                    })
                    (mkModel {
                      id = "claude-sonnet-4-5-20250929";
                      name = "Claude Sonnet 4.5";
                    })
                    (mkModel {
                      id = "claude-sonnet-4-5-thinking";
                      name = "Claude Sonnet 4.5 Thinking";
                      reasoning = true;
                    })
                    (mkModel {
                      id = "claude-sonnet-4-20250514";
                      name = "Claude Sonnet 4";
                    })
                    (mkModel {
                      id = "claude-opus-4-20250514";
                      name = "Claude Opus 4";
                    })
                    (mkModel {
                      id = "claude-haiku-4-5-20251001";
                      name = "Claude Haiku 4.5";
                    })
                    # OpenAI models
                    (mkModel {
                      id = "gpt-5.2";
                      name = "GPT-5.2";
                    })
                    (mkModel {
                      id = "gpt-5.2-codex";
                      name = "GPT-5.2 Codex";
                    })
                    (mkModel {
                      id = "gpt-5.1";
                      name = "GPT-5.1";
                    })
                    (mkModel {
                      id = "gpt-5";
                      name = "GPT-5";
                    })
                    (mkModel {
                      id = "gpt-5-codex";
                      name = "GPT-5 Codex";
                    })
                    # Google Gemini models
                    (mkModel {
                      id = "gemini-3-pro-preview";
                      name = "Gemini 3 Pro";
                    })
                    (mkModel {
                      id = "gemini-3-flash-preview";
                      name = "Gemini 3 Flash";
                    })
                    (mkModel {
                      id = "gemini-2.5-pro";
                      name = "Gemini 2.5 Pro";
                    })
                    (mkModel {
                      id = "gemini-2.5-flash";
                      name = "Gemini 2.5 Flash";
                    })
                    # Z-AI GLM models
                    (mkModel {
                      id = "glm-4.7";
                      name = "GLM 4.7";
                    })
                    (mkModel {
                      id = "glm-4.6";
                      name = "GLM 4.6";
                    })
                  ];
              };
            };
          };
        }
        # All other hosts (macOS + non-kyber Linux): Remote mode - connect to kyber gateway
        // lib.optionalAttrs (!host.isKyber) {
          gateway = {
            mode = "remote";
            # Remote gateway config with client identity and auth token
            remote = {
              url = remoteGatewayUrl;
              tokenFile = "${clawdbotDir}/gateway-token";
              client = {
                name = host.nodeName;
              };
            };
          };
          browser = {
            enabled = true;
            headless = pkgs.stdenv.isLinux; # Headless on Linux, GUI on macOS
          };
        };

      # Anthropic API provider (reads from ~/.config/clawdbot/anthropic-key)
      # Only needed on the gateway (Linux), but harmless to keep on nodes
      providers.anthropic = {
        apiKeyFile = "${clawdbotDir}/anthropic-key";
      };

      # Telegram provider - kyber gateway only (reads from ~/.config/clawdbot/telegram-token)
      providers.telegram = {
        enable = host.isKyber;
        botTokenFile = "${clawdbotDir}/telegram-token";
        allowFrom = [
          983653361
          2104262990
        ];
        groups = {
          "*" = {
            requireMention = false;
          };
          "-1003612372477" = {
            enabled = true;
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
