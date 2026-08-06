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
        template = "${./config.template.toml}";
      };
      names = builtins.attrNames vars;
    in
    pkgs.writeText "hydrate-roborev.sh" (
      builtins.replaceStrings (map (n: "@${n}@") names) (map (n: builtins.toString vars.${n}) names) (
        builtins.readFile ./hydrate.sh
      )
    );
in
{
  home.activation.hydrateRoborevConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${lib.makeBinPath [ pkgs.git ]}:$PATH"
    ${pkgs.bash}/bin/bash "${hydrateScript}" || true
  '';
}
