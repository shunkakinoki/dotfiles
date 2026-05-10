{
  # Clear per-device UserKeyMapping on the Karabiner Virtual HID Keyboard so
  # virtual `caps_lock` events emitted by Karabiner complex_modifications
  # actually toggle Caps Lock instead of being remapped (e.g. to F20) by
  # macOS Modifier Keys preferences.
  #
  # Vendor 1452 (0x5ac) / Product 591 (0x24f) = Karabiner DriverKit VirtualHIDKeyboard.
  # One-shot: applied on `darwin-rebuild`. The Karabiner device may not be
  # registered yet at activation time, so retry briefly.
  system.activationScripts.keyboardKarabinerVhidCapslockFix.text = ''
    for _ in 1 2 3 4 5; do
      if /usr/bin/hidutil list | /usr/bin/grep -q "Karabiner DriverKit VirtualHIDKeyboard"; then
        /usr/bin/hidutil property \
          --matching '{"VendorID":1452,"ProductID":591}' \
          --set '{"UserKeyMapping":[]}' >/dev/null 2>&1 || true
        break
      fi
      sleep 1
    done
  '';
}
