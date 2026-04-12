{ isRunner, lib }:
{
  # Prepend `set +e` so individual brew bundle failures don't abort
  # the entire darwin-rebuild activation. Errors are printed but ignored.
  system.activationScripts.homebrew.text = lib.mkBefore ''
    set +e
  '';

  homebrew = {
    enable = !isRunner && (builtins.getEnv "NIX_OFFLINE" != "1");
    onActivation = {
      autoUpdate = builtins.getEnv "NIX_OFFLINE" != "1";
      upgrade = builtins.getEnv "NIX_OFFLINE" != "1";
      cleanup = "zap";
      extraFlags = [ "--force" ];
    };
    taps = [
      "anomalyco/tap"
      "entireio/tap"
      "homebrew/cask"
      "kurtosis-tech/tap"
      "manaflow-ai/cmux"
      "open-pencil/tap"
      "oven-sh/bun"
      "paradigmxyz/brew"
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
      "mactop"
      "mas"
      "mlx-lm"
      "ollama"
      "opencode"
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
      "yt-dlp"
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
      "cmux"
      "claude-code@latest"
      "claude"
      "codex-app"
      "codex@latest"
      "codexbar"
      "conductor"
      "copilot-money"
      "cursor"
      "discord"
      "docker-desktop"
      "droid"
      "entire"
      "dropbox"
      "figma"
      "firefox"
      "flameshot"
      "font-hack-nerd-font"
      "font-jetbrains-mono-nerd-font"
      "font-jetbrains-mono"
      "ghostty"
      "gitbutler"
      "github"
      "google-chrome"
      "google-drive"
      "hammerspoon"
      "handy"
      "iina"
      "iterm2"
      "karabiner-elements"
      "linear-linear"
      "lm-studio"
      "notion"
      "obsidian"
      "ollama-app"
      "open-pencil"
      "openclaw"
      "opencode-desktop"
      "raycast"
      "repobar"
      "rescuetime"
      "screen-studio"
      "sf-symbols"
      "slack"
      "tailscale-app"
      "telegram-desktop"
      "trae"
      "vlc"
      "visual-studio-code"
      "visual-studio-code@insiders"
      "vscodium"
      "warp"
      "wezterm"
      "whatsapp"
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
