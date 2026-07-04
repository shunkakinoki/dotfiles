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
      # Homebrew 6.0.0 enabled HOMEBREW_REQUIRE_TAP_TRUST by default, refusing
      # to load formulae/casks from non-official taps unless explicitly trusted.
      # Mark our non-official taps as trusted so activation can install them.
      {
        name = "anomalyco/tap";
        trusted = true;
      }
      {
        name = "entireio/tap";
        trusted = true;
      }
      "homebrew/cask"
      {
        name = "kurtosis-tech/tap";
        trusted = true;
      }
      {
        name = "manaflow-ai/cmux";
        trusted = true;
      }
      {
        name = "open-pencil/tap";
        trusted = true;
      }
      {
        name = "oven-sh/bun";
        trusted = true;
      }
      {
        name = "paradigmxyz/brew";
        trusted = true;
      }
      {
        name = "rjyo/moshi";
        trusted = true;
      }
      {
        name = "planetscale/tap";
        trusted = true;
      }
      {
        name = "steipete/tap";
        trusted = true;
      }
    ];
    brews = [
      "argo"
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
      "grafana"
      "graphviz"
      "helm"
      "herdr"
      "jjui"
      "kimi-cli"
      "kurtosis-cli"
      "loki"
      "mactop"
      "mas"
      "moshi-hook"
      "mlx-lm"
      "ollama"
      "opencode"
      "pandoc"
      "pinentry-mac"
      "planetscale/tap/pscale"
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
      "stripe-cli"
      "temporal"
      "tmux"
      "trash"
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
      "claude"
      "claude-code"
      "cmux"
      "codex"
      "codex-app"
      "codexbar"
      "conductor"
      "copilot-money"
      "cursor"
      "devin-desktop"
      "discord"
      "docker-desktop"
      "droid"
      "dropbox"
      "entire"
      "figma"
      "firefox"
      "flameshot"
      "font-hack-nerd-font"
      "font-jetbrains-mono"
      "font-jetbrains-mono-nerd-font"
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
      "linear"
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
      "visual-studio-code"
      "visual-studio-code@insiders"
      "vlc"
      "vscodium"
      "warp"
      "wezterm"
      "whatsapp"
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
