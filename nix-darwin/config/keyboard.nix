{ lib, ... }:
let
  # Karabiner DriverKit Virtual HID Keyboard.
  karabinerVhid = {
    VendorID = 1452; # 0x5ac (Apple-assigned to Karabiner)
    ProductID = 591; # 0x24f
  };

  # Per-device hidutil mapping. Empty list clears any prior remap (e.g. an
  # old Caps Lock -> F20 trick) so virtual `caps_lock` events from Karabiner
  # complex_modifications actually toggle Caps Lock.
  clearMapping = { UserKeyMapping = [ ]; };

  toArg = lib.escapeShellArg;
in
{
  system.activationScripts.keyboardKarabinerVhidCapslockFix.text = ''
    for _ in 1 2 3 4 5; do
      if /usr/bin/hidutil property \
           --matching ${toArg (builtins.toJSON karabinerVhid)} \
           --set ${toArg (builtins.toJSON clearMapping)} \
           >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done
  '';
}
