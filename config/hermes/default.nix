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
        configTemplate = "${./config.yaml}";
        envTemplate = "${./env.template}";
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
  home.activation.hydrateHermesConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash "${hydrateScript}" || true
  '';
}
