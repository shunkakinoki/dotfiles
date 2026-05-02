{
  inputs,
  pkgs,
  ...
}:
{
  programs.noctalia-shell = {
    enable = true;
    package = inputs.noctalia-shell.packages.${pkgs.system}.default;

    settings = {
      bar = {
        clock.format = "%Y/%m/%d %H:%M:%S";
        battery.showLabel = true;
        network.showLabel = false;
        bluetooth.showLabel = false;
      };
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 14;
      };
      notifications = {
        position = "top-right";
      };
      appLauncher = {
        enableClipboardHistory = true;
      };
    };
  };
}
