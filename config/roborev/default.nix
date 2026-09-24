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
        # Matic polls CI for every PR, and pushes arrive in bursts that fan out
        # into panel members; two workers left those bursts queued for hours.
        # Other hosts only review their own commits, so two stays enough.
        maxWorkers = if inputs.host.isMatic then "6" else "2";
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
