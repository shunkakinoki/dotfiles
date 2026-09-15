{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  hydrateScript =
    let
      vars = {
        ciEnabled = if inputs.host.isMatic then "true" else "false";
        # Keep every host to two review workers. A panel fans out child agents,
        # so a higher daemon count multiplies CPU, memory, and git processes.
        maxWorkers = "2";
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
