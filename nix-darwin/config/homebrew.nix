{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall";
    };
    taps = [
      "dracula/install"
    ];
    brews = [
      "mas"
    ];
    casks = [
      "discord"
      "docker"
      "google-chrome"
      "google-drive"
      "raycast"
      "slack"
      "visual-studio-code"
      "zoom"
    ];
    masApps = {
      "Xcode" = 497799835;
    };
  };
}
