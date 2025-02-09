{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall";
    };
    taps = [
      "homebrew/services"
    ];
    brews = [
      "direnv"
      "gnupg"
      "mas"
      "pinentry-mac"
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
