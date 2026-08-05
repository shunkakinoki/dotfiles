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
  home.file.".local/bin/roborev-agent-hook" = {
    source = ../shared/hooks/roborev-agent.sh;
    executable = true;
    force = true;
  };

  home.file.".local/bin/roborev-post-commit" = {
    source = ../shared/hooks/roborev-post-commit.sh;
    executable = true;
    force = true;
  };

  home.activation.hydrateRoborevConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash "${hydrateScript}" || true
  '';
}
