{ isRunner }:
{
  homebrew = {
    enable = !isRunner && (builtins.getEnv "NIX_OFFLINE" != "1");
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
      "paradigmxyz/brew"
      "sst/tap"
    ];
    brews = [
      "bun"
      "claude-squad"
      "cmake"
      "codex"
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
      # "ollama-app"  # FIXME: conflicts_with formula is disabled, uncomment when Homebrew fixes conflict
      "raycast"
      "rescuetime"
      "screen-studio"
      "sf-symbols"
      "slack"
      "visual-studio-code"
      "warp"
      "wezterm"
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
