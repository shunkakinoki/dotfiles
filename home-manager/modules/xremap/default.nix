{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.host) isDesktop;
  inherit (pkgs.stdenv) isLinux;

  hyperPrefix = "C-Alt-Shift-Super-";
  ctrlPrefix = "C-";
  letters = [
    "a"
    "b"
    "c"
    "d"
    "e"
    "f"
    "g"
    "h"
    "i"
    "j"
    "k"
    "l"
    "m"
    "n"
    "o"
    "p"
    "q"
    "r"
    "s"
    "t"
    "u"
    "v"
    "w"
    "x"
    "y"
    "z"
  ];
  # Numbers 3, 4, 5 are intentionally excluded — they pass through as
  # Hyper+3/4/5 for Hyprland screenshot/recording bindings.
  # See: config/hyprland/hyprland.conf (screenshot section)
  numbers = [
    "0"
    "1"
    "2"
    "6"
    "7"
    "8"
    "9"
  ];
  symbols = [
    "semicolon"
    "dot"
    "comma"
    "slash"
    "grave"
    "backslash"
    "leftbrace"
    "rightbrace"
    "apostrophe"
  ];
  navigation = [
    "tab"
    "backspace"
    "left"
    "right"
    "up"
    "down"
  ];
  remapKeys = letters ++ numbers ++ symbols ++ navigation;
  mkRemap =
    keys:
    builtins.listToAttrs (
      map (key: {
        name = "${hyperPrefix}${key}";
        value = "${ctrlPrefix}${key}";
      }) keys
    );
  globalRemap = mkRemap remapKeys;
  # Override copy/paste to Ctrl+Shift (terminal convention: Ctrl+C = SIGINT).
  # All other keys (including z for undo) inherit from globalRemap.
  ghosttyRemap = globalRemap // {
    "${hyperPrefix}c" = "C-Shift-c";
    "${hyperPrefix}v" = "C-Shift-v";
  };
in
{
  config = lib.mkIf (isDesktop && isLinux) {
    services.xremap = {
      enable = true;
      withWlroots = true;
      watch = true;
      deviceNames = [ "keyd virtual keyboard" ];
      config = {
        keymap = [
          {
            name = "Framework Command (Ghostty)";
            application.only = [ "com.mitchellh.ghostty" ];
            remap = ghosttyRemap;
          }
          {
            name = "Framework Command (Global)";
            application.not = [ "com.mitchellh.ghostty" ];
            remap = globalRemap;
          }
        ];
      };
    };

    # Upstream module already sets After/PartOf/Restart; only add extras.
    systemd.user.services.xremap = {
      Unit.StartLimitIntervalSec = 0;
      Service.RestartSec = 3;
    };
  };
}
