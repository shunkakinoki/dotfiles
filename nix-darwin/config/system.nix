{ pkgs, isRunner }:
{
  ids.gids.nixbld = 350;
  system = {
    stateVersion = 4;
    defaults = {
      SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;
      LaunchServices.LSQuarantine = false;
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
        "com.apple.swipescrolldirection" = true;
        "com.apple.keyboard.fnState" = false;
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
      dock = {
        autohide = true;
        persistent-apps = [
          "/System/Applications/Reminders.app"
          "/System/Applications/Notes.app"
          "/System/Applications/Calendar.app"
          "/Applications/Chrome.app"
          "/Applications/Ghostty.app"
          "/System/Applications/Mail.app"
          "/System/Applications/Messages.app"
          "/Applications/Discord.app"
          "/System/Applications/Music.app"
        ];
        orientation = "bottom";
        showhidden = true;
        mru-spaces = false;
        minimize-to-application = true;
        show-recents = false;
        static-only = true;
        tilesize = 48;
        magnification = false;
      };
      trackpad = {
        Clicking = true;
        Dragging = true;
        TrackpadRightClick = true;
        TrackpadThreeFingerDrag = false;
        ActuationStrength = 0;
        FirstClickThreshold = 0;
        SecondClickThreshold = 0;
        TrackpadThreeFingerTapGesture = 2;
      };
    };
    activationScripts.extraActivation.text =
      if !isRunner then
        ''
          softwareupdate --all --install
        ''
      else
        ''
          echo "Skipping activation scripts for runner"
        '';
  };
}
