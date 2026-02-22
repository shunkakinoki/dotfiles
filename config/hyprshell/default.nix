{ inputs, pkgs, ... }:
{
  programs.hyprshell = {
    enable = true;
    package = inputs.hyprshell.packages.${pkgs.system}.hyprshell-nixpkgs;
    systemd.enable = false;
    settings = {
      windows = {
        enable = true;
        switch = {
          enable = true;
          modifier = "super";
        };
      };
    };
  };
}
