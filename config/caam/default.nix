{
  config,
  lib,
  pkgs,
  ...
}:
let
  hydrateScript =
    let
      vars = {
        sed = "${pkgs.gnused}/bin/sed";
        template = "${./config.template.yaml}";
        autoRotate = "true";
      };
      names = builtins.attrNames vars;
    in
    pkgs.writeText "caam-hydrate.sh" (
      builtins.replaceStrings (map (name: "@${name}@") names) (map (
        name: builtins.toString vars.${name}
      ) names) (builtins.readFile ./hydrate.sh)
    );
in
{
  # Hydrate mutable CAAM rotation settings on every host. The vault remains
  # runtime-owned and outside dotfiles.
  home.activation.hydrateCaamConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash "${hydrateScript}"
  '';
}
