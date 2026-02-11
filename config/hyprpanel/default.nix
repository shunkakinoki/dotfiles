{ pkgs, ... }:
{
  programs.hyprpanel = {
    enable = true;
    systemd.enable = false;
    settings = {
      # Bar layout: workspaces left, clock center, modules right
      "bar.layouts" = {
        "0" = {
          left = [
            "dashboard"
            "workspaces"
          ];
          middle = [ "clock" ];
          right = [
            "netstat"
            "cpu"
            "ram"
            "volume"
            "microphone"
            "hyprsunset"
            "hypridle"
            "battery"
            "network"
            "bluetooth"
            "systray"
            "power"
            "notifications"
          ];
        };
      };

      # Dashboard
      "bar.dashboard.icon" = "";

      # Clock
      "bar.clock.format" = "%Y/%m/%d %H:%M:%S";

      # Battery
      "bar.battery.label" = true;

      # Network
      "bar.network.label" = false;

      # Bluetooth
      "bar.bluetooth.label" = false;

      # Workspaces
      "bar.workspaces.show_icons" = true;
      "bar.workspaces.numbered_active_indicator" = "underline";
      "bar.workspaces.show_application_icons" = true;
      "bar.workspaces.workspaceIconMap" = {
        "1" = "";
        "2" = "";
        "3" = "";
        "4" = "󰙯";
      };
      "bar.workspaces.applicationIconMap" = {
        "google-chrome" = "";
        "[sS]lack" = "";
        "[dD]iscord" = "󰙯";
        "com.mitchellh.ghostty" = "";
        "cursor" = "󰨞";
        "1[pP]assword" = "󰌋";
        "code" = "󰨞";
      };

      # Dashboard shortcuts (left)
      "menus.dashboard.shortcuts.left.shortcut1.icon" = "";
      "menus.dashboard.shortcuts.left.shortcut1.tooltip" = "Google Chrome";
      "menus.dashboard.shortcuts.left.shortcut1.command" = "google-chrome-stable";
      "menus.dashboard.shortcuts.left.shortcut2.icon" = "";
      "menus.dashboard.shortcuts.left.shortcut2.tooltip" = "Slack";
      "menus.dashboard.shortcuts.left.shortcut2.command" = "slack";
      "menus.dashboard.shortcuts.left.shortcut3.icon" = "󰙯";
      "menus.dashboard.shortcuts.left.shortcut3.tooltip" = "Discord";
      "menus.dashboard.shortcuts.left.shortcut3.command" = "discord";

      # Dashboard shortcuts (right)
      "menus.dashboard.shortcuts.right.shortcut1.icon" = "󰌾";
      "menus.dashboard.shortcuts.right.shortcut1.tooltip" = "Screen Saver";
      "menus.dashboard.shortcuts.right.shortcut1.command" = "hyprlock";
      "menus.dashboard.shortcuts.right.shortcut2.icon" = "󰉋";
      "menus.dashboard.shortcuts.right.shortcut2.tooltip" = "Files";
      "menus.dashboard.shortcuts.right.shortcut2.command" = "ghostty -e yazi";
      "menus.dashboard.shortcuts.right.shortcut3.icon" = "󰊠";
      "menus.dashboard.shortcuts.right.shortcut3.tooltip" = "Terminal";
      "menus.dashboard.shortcuts.right.shortcut3.command" = "ghostty";

      # Font
      "theme.font.name" = "JetBrainsMono Nerd Font";
      "theme.font.size" = "14px";

      # Bar
      "theme.bar.transparent" = true;
      "theme.bar.floating" = false;

      # Notifications
      "notifications.position" = "top right";
      "notifications.cache_actions" = true;
      "notifications.showActionsOnHover" = false;

      # Scaling (fix dropdown menus overflowing on fractional scale)
      "scalingPriority" = "hyprland";

      # OSD
      "theme.osd.enable" = true;
      "theme.osd.orientation" = "vertical";
      "theme.osd.location" = "right";

      # ── Frosty Translucent Theme ─────────────────────────────────────
      "theme.bar.background" = "#1a1b2680";
      "theme.bar.border.color" = "#ffffff18";
      "theme.bar.buttons.style" = "default";
      "theme.bar.buttons.background" = "#ffffff0d";
      "theme.bar.buttons.icon" = "#ffffffcc";
      "theme.bar.buttons.text" = "#ffffffcc";
      "theme.bar.buttons.hover" = "#ffffff1a";
      "theme.bar.buttons.icon_background" = "#ffffff0d";
      "theme.bar.buttons.borderColor" = "#ffffff18";

      # Dashboard
      "theme.bar.buttons.dashboard.icon" = "#88c0d0";
      "theme.bar.buttons.dashboard.border" = "#ffffff18";
      "theme.bar.buttons.dashboard.background" = "#ffffff0d";

      # Workspaces
      "theme.bar.buttons.workspaces.numbered_active_underline_color" = "#88c0d0";
      "theme.bar.buttons.workspaces.numbered_active_highlighted_text_color" = "#1a1b26";
      "theme.bar.buttons.workspaces.hover" = "#ffffff1a";
      "theme.bar.buttons.workspaces.active" = "#88c0d0";
      "theme.bar.buttons.workspaces.occupied" = "#ffffffaa";
      "theme.bar.buttons.workspaces.available" = "#ffffff55";
      "theme.bar.buttons.workspaces.border" = "#ffffff18";
      "theme.bar.buttons.workspaces.background" = "#ffffff0d";

      # Window title
      "theme.bar.buttons.windowtitle.icon_background" = "#ffffff0d";
      "theme.bar.buttons.windowtitle.icon" = "#ffffffcc";
      "theme.bar.buttons.windowtitle.text" = "#ffffffaa";
      "theme.bar.buttons.windowtitle.border" = "#ffffff18";
      "theme.bar.buttons.windowtitle.background" = "#ffffff0d";

      # Volume
      "theme.bar.buttons.volume.icon_background" = "#ffffff0d";
      "theme.bar.buttons.volume.icon" = "#ffffffcc";
      "theme.bar.buttons.volume.text" = "#ffffffcc";
      "theme.bar.buttons.volume.background" = "#ffffff0d";
      "theme.bar.buttons.volume.border" = "#ffffff18";

      # Network
      "theme.bar.buttons.network.icon_background" = "#ffffff0d";
      "theme.bar.buttons.network.icon" = "#ffffffcc";
      "theme.bar.buttons.network.text" = "#ffffffaa";
      "theme.bar.buttons.network.background" = "#ffffff0d";
      "theme.bar.buttons.network.border" = "#ffffff18";

      # Bluetooth
      "theme.bar.buttons.bluetooth.icon_background" = "#ffffff0d";
      "theme.bar.buttons.bluetooth.icon" = "#ffffffcc";
      "theme.bar.buttons.bluetooth.text" = "#ffffffaa";
      "theme.bar.buttons.bluetooth.background" = "#ffffff0d";
      "theme.bar.buttons.bluetooth.border" = "#ffffff18";

      # Systray
      "theme.bar.buttons.systray.background" = "#ffffff0d";
      "theme.bar.buttons.systray.border" = "#ffffff18";
      "theme.bar.buttons.systray.customIcon" = "#ffffffcc";

      # Battery
      "theme.bar.buttons.battery.icon_background" = "#ffffff0d";
      "theme.bar.buttons.battery.icon" = "#ffffffcc";
      "theme.bar.buttons.battery.text" = "#ffffffaa";
      "theme.bar.buttons.battery.background" = "#ffffff0d";
      "theme.bar.buttons.battery.border" = "#ffffff18";

      # Clock
      "theme.bar.buttons.clock.icon_background" = "#ffffff0d";
      "theme.bar.buttons.clock.icon" = "#ffffffcc";
      "theme.bar.buttons.clock.text" = "#ffffffdd";
      "theme.bar.buttons.clock.background" = "#ffffff0d";
      "theme.bar.buttons.clock.border" = "#ffffff18";

      # Notifications
      "theme.bar.buttons.notifications.total" = "#88c0d0";
      "theme.bar.buttons.notifications.icon_background" = "#ffffff0d";
      "theme.bar.buttons.notifications.icon" = "#ffffffcc";
      "theme.bar.buttons.notifications.background" = "#ffffff0d";
      "theme.bar.buttons.notifications.border" = "#ffffff18";

      # RAM
      "theme.bar.buttons.modules.ram.icon_background" = "#ffffff0d";
      "theme.bar.buttons.modules.ram.icon" = "#ffffffcc";
      "theme.bar.buttons.modules.ram.text" = "#ffffffcc";
      "theme.bar.buttons.modules.ram.background" = "#ffffff0d";
      "theme.bar.buttons.modules.ram.border" = "#ffffff18";

      # CPU
      "theme.bar.buttons.modules.cpu.icon_background" = "#ffffff0d";
      "theme.bar.buttons.modules.cpu.icon" = "#ffffffcc";
      "theme.bar.buttons.modules.cpu.text" = "#ffffffcc";
      "theme.bar.buttons.modules.cpu.background" = "#ffffff0d";
      "theme.bar.buttons.modules.cpu.border" = "#ffffff18";

      # Storage
      "theme.bar.buttons.modules.storage.icon_background" = "#ffffff0d";
      "theme.bar.buttons.modules.storage.icon" = "#b48ead";
      "theme.bar.buttons.modules.storage.text" = "#b48ead";
      "theme.bar.buttons.modules.storage.background" = "#ffffff0d";
      "theme.bar.buttons.modules.storage.border" = "#ffffff18";

      # Netstat
      "theme.bar.buttons.modules.netstat.icon_background" = "#ffffff0d";
      "theme.bar.buttons.modules.netstat.icon" = "#ffffffcc";
      "theme.bar.buttons.modules.netstat.text" = "#ffffffcc";
      "theme.bar.buttons.modules.netstat.background" = "#ffffff0d";
      "theme.bar.buttons.modules.netstat.border" = "#ffffff18";

      # Keyboard Layout
      "theme.bar.buttons.modules.kbLayout.icon_background" = "#ffffff0d";
      "theme.bar.buttons.modules.kbLayout.icon" = "#ffffffcc";
      "theme.bar.buttons.modules.kbLayout.text" = "#ffffffcc";
      "theme.bar.buttons.modules.kbLayout.background" = "#ffffff0d";
      "theme.bar.buttons.modules.kbLayout.border" = "#ffffff18";

      # Updates
      "theme.bar.buttons.modules.updates.icon_background" = "#ffffff0d";
      "theme.bar.buttons.modules.updates.icon" = "#ebcb8b";
      "theme.bar.buttons.modules.updates.text" = "#ebcb8b";
      "theme.bar.buttons.modules.updates.background" = "#ffffff0d";
      "theme.bar.buttons.modules.updates.border" = "#ffffff18";

      # Weather
      "theme.bar.buttons.modules.weather.icon_background" = "#ffffff0d";
      "theme.bar.buttons.modules.weather.icon" = "#ebcb8b";
      "theme.bar.buttons.modules.weather.text" = "#ebcb8b";
      "theme.bar.buttons.modules.weather.background" = "#ffffff0d";
      "theme.bar.buttons.modules.weather.border" = "#ffffff18";

      # Power
      "theme.bar.buttons.modules.power.icon_background" = "#ffffff0d";
      "theme.bar.buttons.modules.power.icon" = "#ffffffcc";
      "theme.bar.buttons.modules.power.background" = "#ffffff0d";
      "theme.bar.buttons.modules.power.border" = "#ffffff18";

      # Submap
      "theme.bar.buttons.modules.submap.background" = "#ffffff0d";
      "theme.bar.buttons.modules.submap.text" = "#88c0d0";
      "theme.bar.buttons.modules.submap.border" = "#ffffff18";
      "theme.bar.buttons.modules.submap.icon" = "#88c0d0";
      "theme.bar.buttons.modules.submap.icon_background" = "#ffffff0d";

      # Hyprsunset
      "theme.bar.buttons.modules.hyprsunset.icon" = "#ffffffcc";
      "theme.bar.buttons.modules.hyprsunset.background" = "#ffffff0d";
      "theme.bar.buttons.modules.hyprsunset.icon_background" = "#ffffff0d";
      "theme.bar.buttons.modules.hyprsunset.text" = "#ffffffcc";
      "theme.bar.buttons.modules.hyprsunset.border" = "#ffffff18";

      # Hypridle
      "theme.bar.buttons.modules.hypridle.icon" = "#ffffffcc";
      "theme.bar.buttons.modules.hypridle.background" = "#ffffff0d";
      "theme.bar.buttons.modules.hypridle.icon_background" = "#ffffff0d";
      "theme.bar.buttons.modules.hypridle.text" = "#ffffffcc";
      "theme.bar.buttons.modules.hypridle.border" = "#ffffff18";

      # Cava
      "theme.bar.buttons.modules.cava.text" = "#88c0d0";
      "theme.bar.buttons.modules.cava.background" = "#ffffff0d";
      "theme.bar.buttons.modules.cava.icon_background" = "#ffffff0d";
      "theme.bar.buttons.modules.cava.icon" = "#88c0d0";
      "theme.bar.buttons.modules.cava.border" = "#ffffff18";

      # Microphone
      "theme.bar.buttons.modules.microphone.border" = "#ffffff18";
      "theme.bar.buttons.modules.microphone.background" = "#ffffff0d";
      "theme.bar.buttons.modules.microphone.text" = "#ffffffcc";
      "theme.bar.buttons.modules.microphone.icon" = "#ffffffcc";
      "theme.bar.buttons.modules.microphone.icon_background" = "#ffffff0d";

      # World Clock
      "theme.bar.buttons.modules.worldclock.text" = "#ffffffcc";
      "theme.bar.buttons.modules.worldclock.background" = "#ffffff0d";
      "theme.bar.buttons.modules.worldclock.icon_background" = "#ffffff0d";
      "theme.bar.buttons.modules.worldclock.icon" = "#ffffffcc";
      "theme.bar.buttons.modules.worldclock.border" = "#ffffff18";

      # ── Menu Theme (frosted glass) ──────────────────────────────────
      "theme.bar.menus.background" = "#1a1b26";
      "theme.bar.menus.cards" = "#ffffff0d";
      "theme.bar.menus.border.color" = "#ffffff18";
      "theme.bar.menus.text" = "#ffffffdd";
      "theme.bar.menus.dimtext" = "#ffffff66";
      "theme.bar.menus.feinttext" = "#ffffff33";
      "theme.bar.menus.label" = "#88c0d0";
      "theme.bar.menus.popover.border" = "#ffffff18";
      "theme.bar.menus.popover.background" = "#1a1b26";
      "theme.bar.menus.popover.text" = "#88c0d0";
      "theme.bar.menus.listitems.active" = "#88c0d0";
      "theme.bar.menus.listitems.passive" = "#ffffffdd";
      "theme.bar.menus.icons.active" = "#88c0d0";
      "theme.bar.menus.icons.passive" = "#ffffff55";
      "theme.bar.menus.switch.enabled" = "#88c0d0";
      "theme.bar.menus.switch.disabled" = "#ffffff22";
      "theme.bar.menus.switch.puck" = "#ffffff44";
      "theme.bar.menus.check_radio_button.active" = "#88c0d0";
      "theme.bar.menus.check_radio_button.background" = "#ffffff0d";
      "theme.bar.menus.buttons.default" = "#88c0d0";
      "theme.bar.menus.buttons.active" = "#81a1c1";
      "theme.bar.menus.buttons.disabled" = "#ffffff22";
      "theme.bar.menus.buttons.text" = "#1a1b26";
      "theme.bar.menus.iconbuttons.active" = "#88c0d0";
      "theme.bar.menus.iconbuttons.passive" = "#ffffffdd";
      "theme.bar.menus.progressbar.foreground" = "#88c0d0";
      "theme.bar.menus.progressbar.background" = "#ffffff22";
      "theme.bar.menus.slider.primary" = "#88c0d0";
      "theme.bar.menus.slider.background" = "#ffffff22";
      "theme.bar.menus.slider.backgroundhover" = "#ffffff33";
      "theme.bar.menus.slider.puck" = "#ffffff44";
      "theme.bar.menus.dropdownmenu.background" = "#1a1b26";
      "theme.bar.menus.dropdownmenu.text" = "#ffffffdd";
      "theme.bar.menus.dropdownmenu.divider" = "#ffffff18";
      "theme.bar.menus.tooltip.background" = "#1a1b26";
      "theme.bar.menus.tooltip.text" = "#ffffffdd";

      # Volume menu
      "theme.bar.menus.menu.volume.card.color" = "#ffffff0d";
      "theme.bar.menus.menu.volume.background.color" = "#1a1b26";
      "theme.bar.menus.menu.volume.border.color" = "#ffffff18";
      "theme.bar.menus.menu.volume.label.color" = "#ebcb8b";
      "theme.bar.menus.menu.volume.text" = "#ffffffdd";
      "theme.bar.menus.menu.volume.listitems.active" = "#ebcb8b";
      "theme.bar.menus.menu.volume.listitems.passive" = "#ffffffdd";
      "theme.bar.menus.menu.volume.iconbutton.active" = "#ebcb8b";
      "theme.bar.menus.menu.volume.iconbutton.passive" = "#ffffffdd";
      "theme.bar.menus.menu.volume.icons.active" = "#ebcb8b";
      "theme.bar.menus.menu.volume.icons.passive" = "#ffffff55";
      "theme.bar.menus.menu.volume.audio_slider.primary" = "#ebcb8b";
      "theme.bar.menus.menu.volume.audio_slider.background" = "#ffffff22";
      "theme.bar.menus.menu.volume.audio_slider.backgroundhover" = "#ffffff33";
      "theme.bar.menus.menu.volume.audio_slider.puck" = "#ffffff44";
      "theme.bar.menus.menu.volume.input_slider.primary" = "#ebcb8b";
      "theme.bar.menus.menu.volume.input_slider.background" = "#ffffff22";
      "theme.bar.menus.menu.volume.input_slider.backgroundhover" = "#ffffff33";
      "theme.bar.menus.menu.volume.input_slider.puck" = "#ffffff44";

      # Network menu
      "theme.bar.menus.menu.network.card.color" = "#ffffff0d";
      "theme.bar.menus.menu.network.background.color" = "#1a1b26";
      "theme.bar.menus.menu.network.border.color" = "#ffffff18";
      "theme.bar.menus.menu.network.label.color" = "#88c0d0";
      "theme.bar.menus.menu.network.text" = "#ffffffdd";
      "theme.bar.menus.menu.network.status.color" = "#ffffff55";
      "theme.bar.menus.menu.network.listitems.active" = "#88c0d0";
      "theme.bar.menus.menu.network.listitems.passive" = "#ffffffdd";
      "theme.bar.menus.menu.network.icons.active" = "#88c0d0";
      "theme.bar.menus.menu.network.icons.passive" = "#ffffff55";
      "theme.bar.menus.menu.network.iconbuttons.active" = "#88c0d0";
      "theme.bar.menus.menu.network.iconbuttons.passive" = "#ffffffdd";
      "theme.bar.menus.menu.network.switch.enabled" = "#88c0d0";
      "theme.bar.menus.menu.network.switch.disabled" = "#ffffff22";
      "theme.bar.menus.menu.network.switch.puck" = "#ffffff44";
      "theme.bar.menus.menu.network.scroller.color" = "#88c0d0";

      # Bluetooth menu
      "theme.bar.menus.menu.bluetooth.card.color" = "#ffffff0d";
      "theme.bar.menus.menu.bluetooth.background.color" = "#1a1b26";
      "theme.bar.menus.menu.bluetooth.border.color" = "#ffffff18";
      "theme.bar.menus.menu.bluetooth.label.color" = "#81a1c1";
      "theme.bar.menus.menu.bluetooth.text" = "#ffffffdd";
      "theme.bar.menus.menu.bluetooth.status" = "#ffffff55";
      "theme.bar.menus.menu.bluetooth.switch_divider" = "#ffffff18";
      "theme.bar.menus.menu.bluetooth.switch.enabled" = "#81a1c1";
      "theme.bar.menus.menu.bluetooth.switch.disabled" = "#ffffff22";
      "theme.bar.menus.menu.bluetooth.switch.puck" = "#ffffff44";
      "theme.bar.menus.menu.bluetooth.listitems.active" = "#81a1c1";
      "theme.bar.menus.menu.bluetooth.listitems.passive" = "#ffffffdd";
      "theme.bar.menus.menu.bluetooth.icons.active" = "#81a1c1";
      "theme.bar.menus.menu.bluetooth.icons.passive" = "#ffffff55";
      "theme.bar.menus.menu.bluetooth.iconbutton.active" = "#81a1c1";
      "theme.bar.menus.menu.bluetooth.iconbutton.passive" = "#ffffffdd";
      "theme.bar.menus.menu.bluetooth.scroller.color" = "#81a1c1";

      # Systray menu
      "theme.bar.menus.menu.systray.dropdownmenu.background" = "#1a1b26";
      "theme.bar.menus.menu.systray.dropdownmenu.text" = "#ffffffdd";
      "theme.bar.menus.menu.systray.dropdownmenu.divider" = "#ffffff18";

      # Battery menu
      "theme.bar.menus.menu.battery.card.color" = "#ffffff0d";
      "theme.bar.menus.menu.battery.background.color" = "#1a1b26";
      "theme.bar.menus.menu.battery.border.color" = "#ffffff18";
      "theme.bar.menus.menu.battery.label.color" = "#a3be8c";
      "theme.bar.menus.menu.battery.text" = "#ffffffdd";
      "theme.bar.menus.menu.battery.listitems.active" = "#a3be8c";
      "theme.bar.menus.menu.battery.listitems.passive" = "#ffffffdd";
      "theme.bar.menus.menu.battery.icons.active" = "#a3be8c";
      "theme.bar.menus.menu.battery.icons.passive" = "#ffffff55";
      "theme.bar.menus.menu.battery.slider.primary" = "#a3be8c";
      "theme.bar.menus.menu.battery.slider.background" = "#ffffff22";
      "theme.bar.menus.menu.battery.slider.backgroundhover" = "#ffffff33";
      "theme.bar.menus.menu.battery.slider.puck" = "#ffffff44";

      # Clock menu
      "theme.bar.menus.menu.clock.card.color" = "#ffffff0d";
      "theme.bar.menus.menu.clock.background.color" = "#1a1b26";
      "theme.bar.menus.menu.clock.border.color" = "#ffffff18";
      "theme.bar.menus.menu.clock.text" = "#ffffffdd";
      "theme.bar.menus.menu.clock.time.time" = "#88c0d0";
      "theme.bar.menus.menu.clock.time.timeperiod" = "#81a1c1";
      "theme.bar.menus.menu.clock.calendar.yearmonth" = "#88c0d0";
      "theme.bar.menus.menu.clock.calendar.weekdays" = "#81a1c1";
      "theme.bar.menus.menu.clock.calendar.paginator" = "#88c0d0";
      "theme.bar.menus.menu.clock.calendar.currentday" = "#88c0d0";
      "theme.bar.menus.menu.clock.calendar.days" = "#ffffffdd";
      "theme.bar.menus.menu.clock.calendar.contextdays" = "#ffffff33";
      "theme.bar.menus.menu.clock.weather.icon" = "#ebcb8b";
      "theme.bar.menus.menu.clock.weather.temperature" = "#ffffffdd";
      "theme.bar.menus.menu.clock.weather.status" = "#88c0d0";
      "theme.bar.menus.menu.clock.weather.stats" = "#81a1c1";
      "theme.bar.menus.menu.clock.weather.thermometer.extremelyhot" = "#bf616a";
      "theme.bar.menus.menu.clock.weather.thermometer.hot" = "#d08770";
      "theme.bar.menus.menu.clock.weather.thermometer.moderate" = "#ebcb8b";
      "theme.bar.menus.menu.clock.weather.thermometer.cold" = "#88c0d0";
      "theme.bar.menus.menu.clock.weather.thermometer.extremelycold" = "#5e81ac";
      "theme.bar.menus.menu.clock.weather.hourly.time" = "#81a1c1";
      "theme.bar.menus.menu.clock.weather.hourly.icon" = "#88c0d0";
      "theme.bar.menus.menu.clock.weather.hourly.temperature" = "#ffffffdd";

      # Dashboard menu
      "theme.bar.menus.menu.dashboard.card.color" = "#ffffff0d";
      "theme.bar.menus.menu.dashboard.background.color" = "#1a1b26";
      "theme.bar.menus.menu.dashboard.border.color" = "#ffffff18";
      "theme.bar.menus.menu.dashboard.profile.name" = "#88c0d0";
      "theme.bar.menus.menu.dashboard.powermenu.shutdown" = "#bf616a";
      "theme.bar.menus.menu.dashboard.powermenu.restart" = "#d08770";
      "theme.bar.menus.menu.dashboard.powermenu.logout" = "#a3be8c";
      "theme.bar.menus.menu.dashboard.powermenu.sleep" = "#88c0d0";
      "theme.bar.menus.menu.dashboard.powermenu.confirmation.card" = "#ffffff0d";
      "theme.bar.menus.menu.dashboard.powermenu.confirmation.background" = "#1a1b26";
      "theme.bar.menus.menu.dashboard.powermenu.confirmation.border" = "#ffffff18";
      "theme.bar.menus.menu.dashboard.powermenu.confirmation.label" = "#88c0d0";
      "theme.bar.menus.menu.dashboard.powermenu.confirmation.body" = "#ffffffdd";
      "theme.bar.menus.menu.dashboard.powermenu.confirmation.confirm" = "#a3be8c";
      "theme.bar.menus.menu.dashboard.powermenu.confirmation.deny" = "#bf616a";
      "theme.bar.menus.menu.dashboard.powermenu.confirmation.button_text" = "#1a1b26";
      "theme.bar.menus.menu.dashboard.shortcuts.background" = "#88c0d0";
      "theme.bar.menus.menu.dashboard.shortcuts.text" = "#1a1b26";
      "theme.bar.menus.menu.dashboard.shortcuts.recording" = "#a3be8c";
      "theme.bar.menus.menu.dashboard.controls.disabled" = "#ffffff22";
      "theme.bar.menus.menu.dashboard.controls.wifi.background" = "#88c0d0";
      "theme.bar.menus.menu.dashboard.controls.wifi.text" = "#1a1b26";
      "theme.bar.menus.menu.dashboard.controls.bluetooth.background" = "#81a1c1";
      "theme.bar.menus.menu.dashboard.controls.bluetooth.text" = "#1a1b26";
      "theme.bar.menus.menu.dashboard.controls.notifications.background" = "#ebcb8b";
      "theme.bar.menus.menu.dashboard.controls.notifications.text" = "#1a1b26";
      "theme.bar.menus.menu.dashboard.controls.volume.background" = "#d08770";
      "theme.bar.menus.menu.dashboard.controls.volume.text" = "#1a1b26";
      "theme.bar.menus.menu.dashboard.controls.input.background" = "#b48ead";
      "theme.bar.menus.menu.dashboard.controls.input.text" = "#1a1b26";
      "theme.bar.menus.menu.dashboard.directories.left.top.color" = "#88c0d0";
      "theme.bar.menus.menu.dashboard.directories.left.middle.color" = "#a3be8c";
      "theme.bar.menus.menu.dashboard.directories.left.bottom.color" = "#bf616a";
      "theme.bar.menus.menu.dashboard.directories.right.top.color" = "#81a1c1";
      "theme.bar.menus.menu.dashboard.directories.right.middle.color" = "#b48ead";
      "theme.bar.menus.menu.dashboard.directories.right.bottom.color" = "#d08770";
      "theme.bar.menus.menu.dashboard.monitors.bar_background" = "#ffffff22";
      "theme.bar.menus.menu.dashboard.monitors.cpu.icon" = "#88c0d0";
      "theme.bar.menus.menu.dashboard.monitors.cpu.bar" = "#88c0d0";
      "theme.bar.menus.menu.dashboard.monitors.cpu.label" = "#88c0d0";
      "theme.bar.menus.menu.dashboard.monitors.ram.icon" = "#a3be8c";
      "theme.bar.menus.menu.dashboard.monitors.ram.bar" = "#a3be8c";
      "theme.bar.menus.menu.dashboard.monitors.ram.label" = "#a3be8c";
      "theme.bar.menus.menu.dashboard.monitors.gpu.icon" = "#ebcb8b";
      "theme.bar.menus.menu.dashboard.monitors.gpu.bar" = "#ebcb8b";
      "theme.bar.menus.menu.dashboard.monitors.gpu.label" = "#ebcb8b";
      "theme.bar.menus.menu.dashboard.monitors.disk.icon" = "#b48ead";
      "theme.bar.menus.menu.dashboard.monitors.disk.bar" = "#b48ead";
      "theme.bar.menus.menu.dashboard.monitors.disk.label" = "#b48ead";

      # Power menu
      "theme.bar.menus.menu.power.background.color" = "#1a1b26";
      "theme.bar.menus.menu.power.border.color" = "#ffffff18";
      "theme.bar.menus.menu.power.buttons.shutdown.background" = "#ffffff0d";
      "theme.bar.menus.menu.power.buttons.shutdown.icon_background" = "#bf616a";
      "theme.bar.menus.menu.power.buttons.shutdown.text" = "#ffffffdd";
      "theme.bar.menus.menu.power.buttons.shutdown.icon" = "#1a1b26";
      "theme.bar.menus.menu.power.buttons.restart.background" = "#ffffff0d";
      "theme.bar.menus.menu.power.buttons.restart.icon_background" = "#d08770";
      "theme.bar.menus.menu.power.buttons.restart.text" = "#d08770";
      "theme.bar.menus.menu.power.buttons.restart.icon" = "#1a1b26";
      "theme.bar.menus.menu.power.buttons.logout.background" = "#ffffff0d";
      "theme.bar.menus.menu.power.buttons.logout.icon_background" = "#a3be8c";
      "theme.bar.menus.menu.power.buttons.logout.text" = "#a3be8c";
      "theme.bar.menus.menu.power.buttons.logout.icon" = "#1a1b26";
      "theme.bar.menus.menu.power.buttons.sleep.background" = "#ffffff0d";
      "theme.bar.menus.menu.power.buttons.sleep.icon_background" = "#88c0d0";
      "theme.bar.menus.menu.power.buttons.sleep.text" = "#88c0d0";
      "theme.bar.menus.menu.power.buttons.sleep.icon" = "#1a1b26";

      # Notifications menu
      "theme.bar.menus.menu.notifications.background" = "#1a1b26";
      "theme.bar.menus.menu.notifications.card" = "#ffffff0d";
      "theme.bar.menus.menu.notifications.border" = "#ffffff18";
      "theme.bar.menus.menu.notifications.label" = "#88c0d0";
      "theme.bar.menus.menu.notifications.no_notifications_label" = "#ffffff44";
      "theme.bar.menus.menu.notifications.switch_divider" = "#ffffff18";
      "theme.bar.menus.menu.notifications.clear" = "#88c0d0";
      "theme.bar.menus.menu.notifications.switch.enabled" = "#88c0d0";
      "theme.bar.menus.menu.notifications.switch.disabled" = "#ffffff22";
      "theme.bar.menus.menu.notifications.switch.puck" = "#ffffff44";
      "theme.bar.menus.menu.notifications.pager.background" = "#ffffff0d";
      "theme.bar.menus.menu.notifications.pager.button" = "#88c0d0";
      "theme.bar.menus.menu.notifications.pager.label" = "#ffffff66";
      "theme.bar.menus.menu.notifications.scrollbar.color" = "#88c0d0";

      # ── OSD Theme ────────────────────────────────────────────────────
      "theme.osd.bar_container" = "#1a1b26cc";
      "theme.osd.icon_container" = "#88c0d0";
      "theme.osd.bar_color" = "#88c0d0";
      "theme.osd.bar_empty_color" = "#ffffff22";
      "theme.osd.bar_overflow_color" = "#bf616a";
      "theme.osd.icon" = "#1a1b26";
      "theme.osd.label" = "#88c0d0";

      # ── Notification Theme (frosted) ────────────────────────────────
      "theme.notification.background" = "#1a1b26cc";
      "theme.notification.actions.background" = "#88c0d0";
      "theme.notification.actions.text" = "#1a1b26";
      "theme.notification.label" = "#88c0d0";
      "theme.notification.border" = "#ffffff18";
      "theme.notification.time" = "#ffffff66";
      "theme.notification.text" = "#ffffffdd";
      "theme.notification.labelicon" = "#88c0d0";
      "theme.notification.close_button.background" = "#88c0d0";
      "theme.notification.close_button.label" = "#1a1b26";
    };
  };
}
