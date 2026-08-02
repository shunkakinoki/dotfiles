{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  managedHost = inputs.host.isKyber || inputs.host.isMatic;
  hydrateScript =
    let
      vars = {
        sed = "${pkgs.gnused}/bin/sed";
        template = "${./config.template.yaml}";
        autoRotate = if managedHost then "true" else "false";
      };
      names = builtins.attrNames vars;
    in
    pkgs.writeText "caam-hydrate.sh" (
      builtins.replaceStrings (map (name: "@${name}@") names) (map (
        name: builtins.toString vars.${name}
      ) names) (builtins.readFile ./hydrate.sh)
    );
in
lib.mkIf managedHost {
  # Hydrate a mutable CAAM config only on Kyber and Matic. The credential vault
  # under ~/.local/share/caam remains runtime-owned and outside dotfiles.
  home.activation.hydrateCaamConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash "${hydrateScript}"
  '';

  # Precheck selects a healthier profile before an interactive Claude session;
  # caam run also handles rate-limit retries for non-interactive invocations.
  programs.fish.interactiveShellInit = lib.mkAfter ''
    if type -q caam
        function claude
            command caam run claude --precheck -- $argv
        end
    end
  '';
}
