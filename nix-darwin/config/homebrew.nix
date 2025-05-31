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
      "kurtosis-tech/tap"
    ];
    brews = [
      "gnupg"
      "helm"
      "kurtosis-cli"
      "mas"
      "pinentry-mac"
      "pnpm"
      "postgresql"
      "protobuf"
      "sheldon"
      "temporal"
    ];
    casks = [
      "beeper"
      "chatgpt"
      "claude"
      "copilot"
      "cursor"
      "discord"
      "docker"
      "dropbox"
      "figma"
      "firefox"
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
      "rescuetime"
      "screen-studio"
      "sf-symbols"
      "slack"
      "visual-studio-code"
      "windsurf"
      "zoom"
    ];
    masApps = {
      "Final Cut Pro" = 424389933;
      "Line" = 539883307;
      "Notability" = 360593530;
      "Xcode" = 497799835;
    };
  };
}
