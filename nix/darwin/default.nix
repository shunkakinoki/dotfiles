{ pkgs, ... }: {
  # User configuration
  users.users.shunkakinoki = {
    home = "/Users/shunkakinoki";
    name = "shunkakinoki";
  };

  # List packages installed in system profile
  environment = {
    systemPackages = with pkgs; [
      vim
      git
      curl
      wget
      coreutils
      gnused
      gnutar
      gzip
      unzip
    ];
    
    # Set default shell to zsh (removed environment.loginShell)
    shells = with pkgs; [ zsh ];
    
    # Add paths to PATH
    systemPath = [ "/opt/homebrew/bin" ];
    
    # Set environment variables
    variables = {
      LANG = "en_US.UTF-8";
      EDITOR = "vim";
    };
  };

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # Necessary for using flakes on this system.
  nix = {
    package = pkgs.nixVersions.stable;
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      warn-dirty = false;
      max-jobs = "auto";
      trusted-users = [ "@admin" ];
    };
    gc = {
      automatic = true;
      interval = { Hour = 23; };
      options = "--delete-older-than 7d";
    };
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';
    optimise.automatic = true;
  };

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      promptInit = "";
    };
    
    # Enable nix-index
    nix-index.enable = true;
    
    # Git configuration (commented out)
    # git = {
    #   enable = true;
    #   config = {
    #     init.defaultBranch = "main";
    #     pull.rebase = true;
    #     push.autoSetupRemote = true;
    #   };
    # };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # macOS System Settings
  system = {
    defaults = {
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
        "com.apple.swipescrolldirection" = false;
        "com.apple.keyboard.fnState" = true;
      };

      dock = {
        autohide = true;
        orientation = "bottom";
        showhidden = true;
        mru-spaces = false;
        minimize-to-application = true;
        show-recents = false;
        static-only = true;
        tilesize = 48;
        magnification = false;
      };
      
      finder = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        FXEnableExtensionChangeWarning = false;
        _FXShowPosixPathInTitle = true;
        CreateDesktop = false;
        QuitMenuItem = true;
        ShowPathbar = true;
        ShowStatusBar = true;
      };

      # Trackpad settings
      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
        TrackpadThreeFingerDrag = true;
        ActuationStrength = 1;
        FirstClickThreshold = 1;
        SecondClickThreshold = 1;
      };

      # Security settings
      CustomSystemPreferences = {
        "com.apple.screensaver" = {
          askForPassword = true;
          askForPasswordDelay = 0;
        };
        "com.apple.screencapture" = {
          location = "~/Desktop";
          type = "png";
        };
      };
    };

    # Add ability to use TouchID for sudo authentication
    activationScripts.postActivation.text = ''
      # Enable Touch ID for sudo
      if ! grep -q "pam_tid.so" /etc/pam.d/sudo; then
        sudo sed -i "" '2i\
auth       sufficient     pam_tid.so
        ' /etc/pam.d/sudo
      fi
    '';

    # Keyboard (commented out)
    # keyboard = {
    #   enableKeyMapping = true;
    #   remapCapsLockToEscape = true;
    # };
  };

  # Fonts (remove fonts.fontDir.enable)
  fonts = {
    packages = with pkgs; [
      pkgs.nerd-fonts.fira-code
      pkgs.nerd-fonts.jetbrains-mono
      pkgs.nerd-fonts.hack
      font-awesome
      hackgen-nf-font
  ];
};

  # Homebrew
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall"; # Less aggressive than "zap"
      extraFlags = [
        "--verbose"
        "--no-quarantine"
        "--force-bottle"
        "--force" # Force install even if there are conflicts
      ];
    };
    global = {
      brewfile = true;
      noLock = true;
      noAutoUpdate = true; # Prevent auto-updates during installation
    };
    # Set installation retries
    installationMode = "sequential"; # Install one at a time
    taps = [
      "homebrew/cask-fonts"
      "homebrew/cask-versions"
      "homebrew/services"
    ];
    brews = [
      "mas"
    ];
    casks = [
      "discord"
      "docker"
      "google-chrome"
      "google-drive"
      "raycast"
      "slack"
      "visual-studio-code"
      "zoom"
    ];
    masApps = {
      "Xcode" = 497799835;
    };
  };

  # Used for backwards compatibility, please read the changelog before changing.
  system.stateVersion = 4;
}
