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
      "oven-sh/bun"
      "sst/tap"
    ];
    brews = [
      "bun"
      "claude-squad"
      "cmake"
      "codex"
      "coreutils"
      "ffmpeg"
      "gnupg"
      "helm"
      "kurtosis-cli"
      "mas"
      "pinentry-mac"
      "pnpm"
      "postgresql"
      "protobuf"
      "sheldon"
      "sst/tap/opencode"
      "temporal"
    ];
    casks = [
      "beeper"
      "block-goose"
      "chatgpt"
      "claude"
      "copilot-money"
      "cursor"
      "discord"
      "docker-desktop"
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
      "granola"
      "hammerspoon"
      "karabiner-elements"
      "linear-linear"
      "lmstudio"
      "notion"
      "ollama-app"
      "raycast"
      "rescuetime"
      "screen-studio"
      "sf-symbols"
      "slack"
      "superhuman"
      "visual-studio-code"
      "warp"
      "windsurf"
      "zed"
      "zoom"
    ];
    masApps = {
      "Apollo" = 6448019325;
      "Final Cut Pro" = 424389933;
      "Line" = 539883307;
      "Notability" = 360593530;
      "Xcode" = 497799835;
    };
  };
}
