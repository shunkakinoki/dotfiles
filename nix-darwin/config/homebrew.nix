{ isRunner }:
{
  homebrew = {
    enable = !isRunner && (builtins.getEnv "NIX_OFFLINE" != "1");
    onActivation = {
      autoUpdate = builtins.getEnv "NIX_OFFLINE" != "1";
      upgrade = builtins.getEnv "NIX_OFFLINE" != "1";
      cleanup = "zap";
      extraFlags = [ "--force" ];
    };
    taps = [
      "homebrew/cask"
      "kurtosis-tech/tap"
      "oven-sh/bun"
      "paradigmxyz/brew"
      "sst/tap"
    ];
    brews = [
      "bun"
      "claude-squad"
      "cmake"
      "colima"
      "coreutils"
      "ffmpeg"
      "gemini-cli"
      "geth"
      "gnupg"
      "graphviz"
      "helm"
      "kurtosis-cli"
      "mas"
      "opencode"
      "ollama"
      "pandoc"
      "pinentry-mac"
      "pnpm"
      "postgresql"
      "protobuf"
      "reth"
      "sheldon"
      "temporal"
    ];
    casks = [
      "antigravity"
      "atuin-desktop"
      "beeper"
      "beekeeper-studio"
      "blender"
      "block-goose"
      "chatgpt"
      "claude"
      "codex"
      "claude-code"
      "conductor"
      "copilot-money"
      "cursor"
      "discord"
      "docker-desktop"
      "droid"
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
      "lm-studio"
      "notion"
      "ollama-app"
      "raycast"
      "rescuetime"
      "screen-studio"
      "sf-symbols"
      "slack"
      "trae"
      "visual-studio-code"
      "visual-studio-code@insiders"
      "vscodium"
      "warp"
      "wezterm"
      "windsurf"
      "zed"
      "zoom"
      "tailscale-app"
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
