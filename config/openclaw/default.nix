{
  config,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs) host;
  homeDir = config.home.homeDirectory;

  mode = if host.isKyber then "gateway" else "client";

  # Use writeText instead of replaceVars to avoid builtins.toFile context warnings
  hydrateScript =
    let
      vars = {
        sed = "${pkgs.gnused}/bin/sed";
        awk = "${pkgs.gawk}/bin/awk";
        template = "${./openclaw.template.json}";
        inherit mode;
      }
      // (
        if host.isKyber then
          {
            chromium = "${pkgs.chromium}";
          }
        else
          {
            chromium = "/unused";
          }
      );
      names = builtins.attrNames vars;
    in
    pkgs.writeText "hydrate.sh" (
      builtins.replaceStrings (map (n: "@${n}@") names) (map (n: builtins.toString vars.${n}) names) (
        builtins.readFile ./hydrate.sh
      )
    );
in
{
  # Hydrate OpenClaw config from .env secrets
  # Gateway mode on Kyber, client mode everywhere else
  home.activation.hydrateOpenclawConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash "${hydrateScript}" || true
  '';
}
