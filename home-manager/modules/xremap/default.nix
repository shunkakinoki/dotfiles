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

  # Hyper = Framework key (keyd: [cmd_hyper:C-A-S-M]) → remapped to Ctrl for macOS-style shortcuts
  hyperPrefix = "C-Alt-Shift-Super-";
  ctrlPrefix = "C-";
  # "f" is excluded — passes through as Hyper+F for Hyprland fullscreen bind.
  # "l" is excluded — passes through as Hyper+L for Hyprland lock screen bind.
  # See: config/hyprland/hyprland.conf (Window Management section, Lock Screen section)
  letters = [
    "a"
    "b"
    "c"
    "d"
    "e"
    "g"
    "h"
    "i"
    "j"
    "k"
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
  # Framework+key → Ctrl+key for all apps (macOS-style shortcuts)
  globalRemap = mkRemap remapKeys;
  # Ghostty: Framework+C/V → Ctrl+Shift+C/V (terminal convention: Ctrl+C = SIGINT)
  ghosttyRemap = globalRemap // {
    "${hyperPrefix}c" = "C-Shift-c";
    "${hyperPrefix}v" = "C-Shift-v";
  };
in
{
  config = lib.mkMerge [
    {
      # Explicitly disable to suppress the "module imported but not enabled" warning.
      services.xremap.enable = lib.mkDefault false;
    }
    (lib.mkIf (isDesktop && isLinux) {
      services.xremap = {
        enable = true;
        withWlroots = true;
        watch = true;
        # Only intercept keyd output — SUPER (CapsLock/RightAlt) goes straight to Hyprland
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
    })
  ];
}
