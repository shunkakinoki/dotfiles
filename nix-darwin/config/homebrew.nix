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
    ];
    brews = [
      "direnv"
      "gnupg"
      "mas"
      "pnpm"
      "pinentry-mac"
      "sheldon"
    ];
    casks = [
      "chatgpt"
      "claude"
      "copilot"
      "cursor"
      "discord"
      "docker"
      "figma"
      "font-hack-nerd-font"
      "font-jetbrains-mono"
      "font-jetbrains-mono-nerd-font"
      "ghostty"
      "github"
      "google-chrome"
      "google-drive"
      "hammerspoon"
      "karabiner-elements"
      "linear-linear"
      "notion"
      "raycast"
      "screen-studio"
      "sf-symbols"
      "signal"
      "slack"
      "visual-studio-code"
      "zoom"
    ];
    masApps = {
      "Notability" = 360593530;
      "Xcode" = 497799835;
      "Zerion" = 1456732565;
    };
  };
}
