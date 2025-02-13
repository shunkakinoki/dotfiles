{ isRunner }:
{
  homebrew = {
    enable = !isRunner;
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
      "figma"
      "ghostty"
      "google-chrome"
      "google-drive"
      "hammerspoon"
      "karabiner-elements"
      "linear-linear"
      "notion"
      "raycast"
      "screen-studio"
      "sf-symbols"
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
