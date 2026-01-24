{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs) env host;
  homeDir = config.home.homeDirectory;

  # Build clawdbot from source using pnpm
  clawdbotSrc = pkgs.fetchFromGitHub {
    owner = "clawdbot";
    repo = "clawdbot";
    rev = "v2026.1.22";
    hash = "sha256-DJZulGqo2E7XvitR3kYKme9vqSfQyYs9I9fsBIpqQdQ=";
  };

  clawdbotPkg = pkgs.stdenv.mkDerivation rec {
    pname = "clawdbot";
    version = "2026.1.22";
    src = clawdbotSrc;

    nativeBuildInputs = [
      pkgs.nodejs_22
      pkgs.pnpm_10
      pkgs.pnpm_10.configHook
      pkgs.makeWrapper
    ];

    pnpmDeps = pkgs.pnpm_10.fetchDeps {
      inherit pname version src;
      hash = "sha256-LSqWBa2etVDA4CZSRsaVOEt9Hp2CfAmbnLoiqxjSjOY=";
      fetcherVersion = 1;
    };

    buildPhase = ''
      runHook preBuild
      pnpm run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/lib/clawdbot
      # Copy all relevant directories for the monorepo
      cp -r dist node_modules package.json $out/lib/clawdbot/
      cp -r extensions ui apps tools $out/lib/clawdbot/ 2>/dev/null || true
      # Remove broken symlinks
      find $out -xtype l -delete
      makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/clawdbot \
        --add-flags "$out/lib/clawdbot/dist/cli.js"
      runHook postInstall
    '';

    meta = with lib; {
      description = "Clawdbot gateway";
      homepage = "https://github.com/clawdbot/clawdbot";
      license = licenses.mit;
      platforms = platforms.unix;
    };
  };

  # Template config file
  templateFile = ../../../config/clawdbot/clawdbot.template.json;

  # Hydrate script with injected paths
  hydrateScript = pkgs.replaceVars ../../../config/clawdbot/hydrate.sh {
    template = templateFile;
    sed = "${pkgs.gnused}/bin/sed";
    chromium = pkgs.chromium;
    clawdbot = clawdbotPkg;
  };
in
# Only enable on kyber (gateway host) and outside CI
lib.mkIf (host.isKyber && !env.isCI) {
  # Add clawdbot to PATH
  home.packages = [ clawdbotPkg ];

  # Ensure secrets directory exists
  home.activation.clawdbotSecretsDir = lib.mkIf (lib ? hm && lib.hm ? dag) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${homeDir}/.config/clawdbot"
      chmod 700 "${homeDir}/.config/clawdbot"
    ''
  );

  # Extract secrets from cliproxyapi auth
  home.activation.clawdbotSecrets = lib.mkIf (lib ? hm && lib.hm ? dag) (
    lib.hm.dag.entryAfter [ "writeBoundary" "clawdbotSecretsDir" ] ''
      SECRETS_DIR="${homeDir}/.config/clawdbot"
      CCS_AUTH="${homeDir}/.ccs/cliproxy/auth"

      # Extract Anthropic key from ccs auth if available
      if [ -d "$CCS_AUTH" ]; then
        ANTHROPIC_FILE=$(find "$CCS_AUTH" -name "*.json" -exec grep -l "anthropic" {} \; 2>/dev/null | head -1)
        if [ -n "$ANTHROPIC_FILE" ] && [ -f "$ANTHROPIC_FILE" ]; then
          ${pkgs.jq}/bin/jq -r '.api_key // empty' "$ANTHROPIC_FILE" 2>/dev/null | tr -d '\n' > "$SECRETS_DIR/anthropic-key" || true
        fi
      fi

      # Extract cliproxy key from .env if available
      ENV_FILE="${homeDir}/dotfiles/.env"
      if [ -f "$ENV_FILE" ]; then
        CLIPROXY_KEY=$(grep -E "^CLIPROXY_API_KEY=" "$ENV_FILE" 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d '\n' || true)
        if [ -n "$CLIPROXY_KEY" ]; then
          echo -n "$CLIPROXY_KEY" > "$SECRETS_DIR/cliproxy-key"
        fi

        TELEGRAM_TOKEN=$(grep -E "^TELEGRAM_BOT_TOKEN=" "$ENV_FILE" 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d '\n' || true)
        if [ -n "$TELEGRAM_TOKEN" ]; then
          echo -n "$TELEGRAM_TOKEN" > "$SECRETS_DIR/telegram-token"
        fi

        GATEWAY_TOKEN=$(grep -E "^CLAWDBOT_GATEWAY_TOKEN=" "$ENV_FILE" 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d '\n' || true)
        if [ -n "$GATEWAY_TOKEN" ]; then
          echo -n "$GATEWAY_TOKEN" > "$SECRETS_DIR/gateway-token"
        fi
      fi

      # Ensure proper permissions
      chmod 600 "$SECRETS_DIR"/*.key "$SECRETS_DIR"/*-token 2>/dev/null || true
    ''
  );

  # Systemd service for clawdbot gateway
  systemd.user.services.clawdbot-gateway = {
    Unit = {
      Description = "Clawdbot gateway";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash ${hydrateScript}";
      Restart = "always";
      RestartSec = "5s";
      Environment = [
        "HOME=${homeDir}"
      ];
      WorkingDirectory = "${homeDir}/.clawdbot";
      StandardOutput = "append:/tmp/clawdbot/clawdbot-gateway.log";
      StandardError = "append:/tmp/clawdbot/clawdbot-gateway.log";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Create log directory
  home.activation.clawdbotLogDir = lib.mkIf (lib ? hm && lib.hm ? dag) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p /tmp/clawdbot
    ''
  );
}
