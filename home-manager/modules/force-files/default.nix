{ lib, ... }:
let
  option = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule { config.force = lib.mkDefault true; });
  };
in
{
  # Apps rewrite or self-update managed files in place, and activation aborts
  # once the backup path is already taken, so every managed file overwrites.
  options.home.file = option;
  options.xdg.configFile = option;
  options.xdg.dataFile = option;
  options.xdg.stateFile = option;
  options.xdg.cacheFile = option;

  # These modules pass their own force flag through, overriding the default.
  config.gtk.gtk2.force = true;
  config.programs.atuin.forceOverwriteSettings = true;
}
