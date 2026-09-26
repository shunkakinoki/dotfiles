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
        ciEnabled = if inputs.host.isKamino && inputs.host.nodeName == "kamino7" then "true" else "false";
        # Kamino7 is the dedicated CI runner. Its systemd CPU quota bounds bursts
        # from twelve review workers; other hosts keep two local workers.
        maxWorkers = if inputs.host.isKamino && inputs.host.nodeName == "kamino7" then "12" else "2";
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
