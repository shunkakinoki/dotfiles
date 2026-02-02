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

  hydrateScript = pkgs.replaceVars ./hydrate.sh ({
    sed = "${pkgs.gnused}/bin/sed";
    template = ./openclaw.template.json;
    inherit mode;
  } // (if host.isKyber then {
    chromium = pkgs.chromium;
    openclaw = "${homeDir}/.bun";
  } else {
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
}
