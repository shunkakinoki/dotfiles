{ pkgs, ... }:
let
  gnome-control-center-wrapper = pkgs.writeShellScript "gnome-control-center-wrapper" ''
    export XDG_CURRENT_DESKTOP=GNOME
    export XDG_DATA_DIRS="${pkgs.gnome-shell}/share/gsettings-schemas/${pkgs.gnome-shell.name}:$XDG_DATA_DIRS"
    exec ${pkgs.gnome-control-center}/bin/gnome-control-center "$@"
  '';
in
{
  xdg.configFile."rofi/config.rasi" = {
    source = ./config.rasi;
    force = true;
  };

  xdg.desktopEntries = {
    restart = {
      name = "Restart";
      exec = "systemctl reboot";
      icon = "system-reboot";
      categories = [ "System" ];
      noDisplay = false;
    };
    shutdown = {
      name = "Shutdown";
      exec = "systemctl poweroff";
      icon = "system-shutdown";
      categories = [ "System" ];
      noDisplay = false;
    };
    suspend = {
      name = "Suspend";
      exec = "systemctl suspend";
      icon = "system-suspend";
      categories = [ "System" ];
      noDisplay = false;
    };
    lock-screen = {
      name = "Lock Screen";
      exec = "hyprlock";
      icon = "system-lock-screen";
      categories = [ "System" ];
      noDisplay = false;
    };
    screen-saver = {
      name = "Screen Saver";
      exec = "hyprlock";
      icon = "preferences-desktop-screensaver";
      categories = [ "System" ];
      noDisplay = false;
    };
    logout = {
      name = "Logout";
      exec = "hyprctl dispatch exit";
      icon = "system-log-out";
      categories = [ "System" ];
      noDisplay = false;
    };
    toggle-wifi = {
      name = "Toggle WiFi";
      exec = "nmcli radio wifi toggle";
      icon = "network-wireless";
      categories = [ "System" ];
      noDisplay = false;
    };
    audio-settings = {
      name = "Audio Settings";
      exec = "pavucontrol";
      icon = "audio-volume-high";
      categories = [
        "System"
        "Settings"
      ];
      noDisplay = false;
    };
    bluetooth-settings = {
      name = "Bluetooth Settings";
      exec = "blueman-manager";
      icon = "bluetooth";
      categories = [
        "System"
        "Settings"
      ];
      noDisplay = false;
    };
    screenshot-region = {
      name = "Screenshot Region";
      exec = "hyprshot -m region";
      icon = "accessories-screenshot";
      categories = [ "Utility" ];
      noDisplay = false;
    };
    color-picker = {
      name = "Color Picker";
      exec = "hyprpicker -a";
      icon = "color-select";
      categories = [ "Utility" ];
      noDisplay = false;
    };
    wifi-settings = {
      name = "WiFi Settings";
      exec = "${gnome-control-center-wrapper} wifi";
      icon = "network-wireless";
      categories = [
        "System"
        "Settings"
      ];
      noDisplay = false;
    };
    network-connections = {
      name = "Network Connections";
      exec = "nm-connection-editor";
      icon = "preferences-system-network";
      categories = [
        "System"
        "Settings"
      ];
      noDisplay = false;
    };
  };
}
