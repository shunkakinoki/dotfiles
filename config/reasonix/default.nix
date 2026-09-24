{
  config,
  pkgs,
  ...
}:
let
  hydrateScript =
    let
      vars = {
        template = "${./config.toml}";
        tomlq = "${pkgs.yq}/bin/tomlq";
        awk = "${pkgs.gawk}/bin/awk";
      };
      names = builtins.attrNames vars;
    in
    pkgs.writeText "reasonix-hydrate.sh" (
      builtins.replaceStrings (map (n: "@${n}@") names) (map (n: vars.${n}) names) (
        builtins.readFile ./hydrate.sh
      )
    );
in
{
  # Reasonix migrates and rewrites config.toml at runtime, so upsert the managed
  # provider into it instead of replacing the file.
  home.activation.hydrateReasonixConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash "${hydrateScript}" || true
  '';
}
