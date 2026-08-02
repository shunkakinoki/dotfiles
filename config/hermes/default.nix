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
        configTemplate = "${./config.template.yaml}";
        envTemplate = "${./env.template}";
        soul = "${../../SOUL.md}";
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
  home.file.".hermes/plugins/moshi-hooks/__init__.py" = {
    source = pkgs.replaceVars ./moshi-hooks.py {
      moshiHook = "${pkgs.moshi-hook}/bin/moshi-hook";
    };
    force = true;
  };

  home.file.".hermes/plugins/moshi-hooks/plugin.yaml" = {
    source = ./moshi-hooks-plugin.yaml;
    force = true;
  };

  home.activation.hydrateHermesConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash "${hydrateScript}" || true
  '';
}
