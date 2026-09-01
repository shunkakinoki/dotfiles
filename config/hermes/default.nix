{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs) host;

  mode = if host.isKyber then "gateway" else "client";

  hydrateScript =
    let
      vars = {
        sed = "${pkgs.gnused}/bin/sed";
        awk = "${pkgs.gawk}/bin/awk";
        git = "${pkgs.git}/bin/git";
        configTemplate = "${./config.template.yaml}";
        envTemplate = "${./env.template}";
        soul = "${../../SOUL.md}";
        tracesPluginManifest = "${../../generated/hooks/traces/hermes/plugin.yaml}";
        tracesPluginModule = "${../../generated/hooks/traces/hermes/__init__.py}";
        inherit mode;
      };
      names = builtins.attrNames vars;
    in
    pkgs.writeText "hermes-hydrate.sh" (
      builtins.replaceStrings (map (n: "@${n}@") names) (map (n: builtins.toString vars.${n}) names) (
        builtins.readFile ./hydrate.sh
      )
    );
in
{
  home.activation.hydrateHermesConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash "${hydrateScript}" || true
  '';
}
