{ lib, pkgs, ... }:
let
  hydrateScript = pkgs.writeText "handy-hydrate.sh" (
    builtins.replaceStrings [ "@sed@" ] [ "${pkgs.gnused}/bin/sed" ] (builtins.readFile ./hydrate.sh)
  );
in
{
  # Handy mutates settings_store.json at runtime (UI changes), so we copy via
  # activation rather than symlinking the read-only Nix store. The template
  # holds an __OPENROUTER_API_KEY__ placeholder hydrated from ~/dotfiles/.env.
  home.activation.hydrateHandy = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash ${hydrateScript} || true
  '';
}
