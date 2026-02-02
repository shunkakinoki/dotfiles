{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs) host;
  homeDir = config.home.homeDirectory;

  mode = if host.isKyber then "gateway" else "client";

  hydrateScript = pkgs.replaceVars ../../config/openclaw/hydrate.sh ({
    sed = "${pkgs.gnused}/bin/sed";
    template = ../../config/openclaw/openclaw.template.json;
    inherit mode;
  } // (if host.isKyber then {
    chromium = pkgs.chromium;
    openclaw = "${homeDir}/.bun";
  } else {
    # Client mode: gateway-only placeholders are unused but must be substituted
    chromium = "/unused";
    openclaw = "/unused";
  }));
in
{
  # Hydrate OpenClaw config from .env secrets
  # Gateway mode on Kyber, client mode everywhere else
  home.activation.hydrateOpenclawConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${homeDir}/.openclaw
    ${pkgs.bash}/bin/bash ${hydrateScript} || true
  '';
} // lib.optionalAttrs (host.isKyber) {
  # Systemd service for OpenClaw gateway
  systemd.user.services.openclaw-gateway = {
    Unit = {
      Description = "OpenClaw gateway";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${homeDir}/.bun/bin/openclaw gateway --port 18789";
      Restart = "always";
      RestartSec = "5s";
      Environment = [
        "HOME=${homeDir}"
        "PATH=${homeDir}/.local/bin:${homeDir}/.bun/bin:${homeDir}/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin"
      ];
      WorkingDirectory = "${homeDir}/.openclaw";
      StandardOutput = "append:/tmp/openclaw/openclaw-gateway.log";
      StandardError = "append:/tmp/openclaw/openclaw-gateway.log";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
