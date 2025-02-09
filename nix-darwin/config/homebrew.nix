{
  homebrew = {
    enable = builtins.getEnv "CI" != "true";
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
      extraFlags = [ "--force" ];
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
      "sheldon"
    ];
    casks = [
      "chatgpt"
      "cursor"
      "discord"
      "docker"
      "ghostty"
      "google-chrome"
      "google-drive"
      "linear-linear"
      "notion"
      "raycast"
      "screen-studio"
      "slack"
      "visual-studio-code"
      "zoom"
    ];
    masApps = {
      "Notability" = 360593530;
      "Xcode" = 497799835;
    };
  };
}
