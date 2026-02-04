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
      "steipete/tap"
    ];
    brews = [
      "bun"
      "claude-squad"
      "cliproxyapi"
      "cmake"
      "coder"
      "colima"
      "coreutils"
      "ffmpeg"
      "gemini-cli"
      "geth"
      "gnupg"
      "graphviz"
      "helm"
      "jjui"
      "kimi-cli"
      "kurtosis-cli"
      "mas"
      "opencode"
      "ollama"
      "pandoc"
      "pinentry-mac"
      "pnpm"
      "postgresql"
      {
        name = "postgresql";
        link = false;
      }
      {
        name = "postgresql@18";
        link = true;
      }
      "protobuf"
      "pulumi"
      "qwen-code"
      "reth"
      "sheldon"
      "sshpass"
      "temporal"
      "watchexec"
    ];
    casks = [
      "antigravity"
      "atuin-desktop"
      "balenaetcher"
      "beekeeper-studio"
      "beeper"
      "blender"
      "block-goose"
      "chatgpt"
      "claude-code"
      "claude"
      "codex-app"
      "codex"
      "codexbar"
      "conductor"
      "copilot-money"
      "cursor"
      "discord"
      "docker-desktop"
      "droid"
      "dropbox"
      "figma"
      "firefox"
      "flameshot"
      "font-hack-nerd-font"
      "font-jetbrains-mono-nerd-font"
      "font-jetbrains-mono"
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
      "openclaw"
      "opencode-desktop"
      "raycast"
      "repobar"
      "rescuetime"
      "screen-studio"
      "sf-symbols"
      "slack"
      "tailscale-app"
      "trae"
      "visual-studio-code"
      "visual-studio-code@insiders"
      "vscodium"
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
