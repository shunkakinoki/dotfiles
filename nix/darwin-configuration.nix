{ pkgs, ... }: {
  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    coreutils
  ];

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # Necessary for using flakes on this system.
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      warn-dirty = false;
      max-jobs = "auto";
      trusted-users = [ "@admin" ];
    };
    gc = {
      automatic = true;
      interval = { Hour = 24; };
      options = "--delete-older-than 7d";
    };
  };

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    promptInit = "";
  };

  # Set Git to use SSH
  programs.ssh = {
    enable = true;
    knownHosts = {};
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # macOS System Settings
  system.defaults = {
    dock = {
      autohide = true;
      orientation = "bottom";
      showhidden = true;
      mru-spaces = false;
      minimize-to-application = true;
      show-recents = false;
      static-only = true;
    };
    
    finder = {
      AppleShowAllExtensions = true;
      FXEnableExtensionChangeWarning = false;
      _FXShowPosixPathInTitle = true;
      CreateDesktop = false;
      QuitMenuItem = true;
    };

    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;
    };

    # Trackpad settings
    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
    };

    # Keyboard settings
    keyboard = {
      enableKeyMapping = true;
    };

    # Security settings
    CustomSystemPreferences = {
      "com.apple.screensaver" = {
        askForPassword = true;
        askForPasswordDelay = 0;
      };
    };
  };

  # Add ability to used TouchID for sudo authentication
  security.pam.enableSudoTouchIdAuth = true;

  # Keyboard
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  # Fonts
  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [
      (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" ]; })
    ];
  };

  # Used for backwards compatibility, please read the changelog before changing.
  system.stateVersion = 4;
} 