{ ... }:
{
  xdg.configFile."tmuxinator/primary.yml".source = ./primary.yml;
  xdg.configFile."tmuxinator/mobile.yml".source = ./mobile.yml;
  xdg.configFile."tmuxinator/work.yml".source = ./work.yml;
  xdg.configFile."tmuxinator/desktop.yml".source = ./desktop.yml;
}
