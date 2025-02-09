{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall";
    };
    taps = [
      "homebrew/cask"
      "homebrew/services"
    ];
    brews = [
      "direnv"
      "gnupg"
      "mas"
      "pinentry-mac"
    ];
    casks = [
      "cursor"
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
