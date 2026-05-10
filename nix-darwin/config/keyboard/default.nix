{ lib, pkgs }:
let
  # Per-device hidutil UserKeyMapping entries applied on activation.
  #
  # macOS persists per-device modifier-key remaps in IORegistry, not in any
  # plist that nix-darwin can write to via `system.defaults`. The only way to
  # express "this device should have this mapping" is to call `hidutil` after
  # the device has registered.
  #
  # Add new entries here to extend (e.g. for other physical keyboards).
  hidUserKeyMappings = [
    {
      # Karabiner DriverKit Virtual HID Keyboard.
      # Empty UserKeyMapping clears any prior remap (e.g. an older Caps Lock
      # -> F20 trick) so virtual `caps_lock` events emitted by Karabiner
      # complex_modifications actually toggle Caps Lock.
      match = {
        VendorID = 1452;
        ProductID = 591;
      };
      mapping = {
        UserKeyMapping = [ ];
      };
    }
  ];

  perDeviceCalls = lib.concatMapStringsSep "\n" (
    m:
    "apply_mapping "
    + lib.escapeShellArg (builtins.toJSON m.match)
    + " "
    + lib.escapeShellArg (builtins.toJSON m.mapping)
  ) hidUserKeyMappings;

  applyScript = builtins.readFile (
    pkgs.replaceVars ./apply-hid-user-key-mappings.sh {
      hidutilBin = "/usr/bin/hidutil";
      inherit perDeviceCalls;
    }
  );
in
{
  system.activationScripts.keyboardHidUserKeyMappings.text = applyScript;
}
