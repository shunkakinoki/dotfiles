{ lib, pkgs, ... }:
let
  moshiHooks = pkgs.replaceVars ./moshi-hooks.json {
    moshiHook = "${pkgs.moshi-hook}/bin/moshi-hook";
  };
  plugin = pkgs.runCommand "grok-plugin" { } ''
    cp -R ${./plugin} "$out"
    chmod -R u+w "$out"
  '';
in
{
  home.file.".grok/hooks/moshi-hooks.json" = {
    source = moshiHooks;
    force = true;
  };

  # Use activation script instead of a home.file symlink.
  # Grok performs atomic writes to config.toml that break symlinks, so force-copy on each switch.
  #
  # The activation also installs a Claude Code-format plugin that wires the
  # shared security hooks independently from the Nix-owned Moshi hook file.
  home.activation.grokConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${./config.toml}" "${plugin}"
  '';
}
