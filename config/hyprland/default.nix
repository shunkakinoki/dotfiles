{
  config,
  inputs,
  pkgs,
  ...
}:
let
  hyprexpoPlugin = pkgs.hyprlandPlugins.hyprexpo;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    systemd.enable = false;
    extraConfig = ''
      plugin = ${hyprexpoPlugin}/lib/libhyprexpo.so
      exec-once = ${pkgs.hyprpanel}/bin/hyprpanel
    ''
    + builtins.readFile ./hyprland.conf;
  };

  xdg.configFile."hypr/hypridle.conf" = {
    source = ./hypridle.conf;
    force = true;
  };
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        grace = 0;
      };

      auth = {
        fingerprint = {
          enabled = true;
        };
      };

      background = [
        {
          monitor = "";
          path = "screenshot";
          blur_passes = 3;
          blur_size = 8;
          contrast = 0.8;
          brightness = 0.7;
          vibrancy = 0.17;
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "600, 100";
          outline_thickness = 4;
          dots_size = 0.26;
          dots_spacing = 0.15;
          dots_center = true;
          outer_color = "rgba(88c0d0cc)";
          inner_color = "rgba(1a1b26cc)";
          font_color = "rgba(ffffffdd)";
          font_family = "JetBrainsMono Nerd Font";
          font_size = 32;
          fade_on_empty = false;
          placeholder_text = "  Enter Password 󰈷";
          fail_text = "Wrong";
          rounding = 0;
          shadow_passes = 0;
          position = "0, 0";
          halign = "center";
          valign = "center";
        }
      ];

      label = [
        {
          # Time display
          monitor = "";
          text = ''cmd[update:1000] date +"%H:%M:%S"'';
          color = "rgba(ffffffdd)";
          font_size = 64;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 150";
          halign = "center";
          valign = "center";
        }
        {
          # Fingerprint prompt
          monitor = "";
          text = "$FPRINTPROMPT";
          text_align = "center";
          color = "rgba(ffffffdd)";
          font_size = 24;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, -100";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };

  xdg.configFile."hypr/scripts/toggle-terminal.sh" = {
    source = ./scripts/toggle-terminal.sh;
    executable = true;
    force = true;
  };
  xdg.configFile."hypr/scripts/record-screen.sh" = {
    source = ./scripts/record-screen.sh;
    executable = true;
    force = true;
  };
}
