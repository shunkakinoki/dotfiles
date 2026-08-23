{
  config,
  pkgs,
  ...
}:
let
  hydrateScript = pkgs.writeText "dsh-hydrate.sh" (
    builtins.replaceStrings [ "@template@" "@yq@" ] [ "${./settings.yaml}" "${pkgs.yq}/bin/yq" ] (
      builtins.readFile ./hydrate.sh
    )
  );
in
{
  # DSH owns settings.yaml at runtime, so merge the declarative defaults into
  # it instead of replacing its onboarding and user-managed state.
  home.activation.hydrateDshSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash "${hydrateScript}" || true
  '';
}
