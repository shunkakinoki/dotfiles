{
  pkgs,
  isRunner,
  username,
}:
{
  ids.gids.nixbld = 350;

  # Set environment variables for GUI applications (VS Code, etc.)
  launchd.user.envVariables = {
    SHELL = "${pkgs.bash}/bin/bash";
    GOROOT = "/etc/go-root";
    GOPATH = "/Users/${username}/go";
    PATH = "/Users/${username}/go/bin:/etc/profiles/per-user/${username}/bin:/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
  };

  environment.etc."go-root".source = "${pkgs.go}/share/go";

  # Avoid nixpkgs options.json warning during docs generation.
  documentation.enable = false;

  system = {
    stateVersion = 4;
    primaryUser = username;
    defaults = {
      ".GlobalPreferences" = {
        "com.apple.sound.beep.sound" = /System/Library/Sounds/Blow.aiff;
      };
      ActivityMonitor = {
        OpenMainWindow = true;
        ShowCategory = 100;
      };
      SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;
      LaunchServices.LSQuarantine = false;
      CustomSystemPreferences = {
        "com.apple.screensaver" = {
          askForPassword = true;
          askForPasswordDelay = 0;
          idleTime = 600;
        };
        "com.apple.screencapture" = {
          location = "~/Desktop";
          type = "png";
        };
      };
      NSGlobalDomain = {
        AppleICUForce24HourTime = true;
        AppleInterfaceStyle = "Dark";
        AppleInterfaceStyleSwitchesAutomatically = true;
        AppleShowAllExtensions = true;
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = true;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        PMPrintingExpandedStateForPrint = true;
        PMPrintingExpandedStateForPrint2 = true;
        "com.apple.keyboard.fnState" = false;
        "com.apple.sound.beep.volume" = 1.0;
        "com.apple.springing.delay" = 0.5;
        "com.apple.springing.enabled" = true;
        "com.apple.swipescrolldirection" = true;
        "com.apple.trackpad.forceClick" = true;
        "com.apple.trackpad.scaling" = 3.0;
      };
      WindowManager = {
        AppWindowGroupingBehavior = false;
        AutoHide = true;
        EnableTiledWindowMargins = false;
        GloballyEnabled = false;
        HideDesktop = false;
        StageManagerHideWidgets = false;
        StandardHideWidgets = false;
      };
      finder = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv";
        NewWindowTarget = "Recents";
        _FXShowPosixPathInTitle = true;
        CreateDesktop = false;
        QuitMenuItem = true;
        ShowExternalHardDrivesOnDesktop = true;
        ShowHardDrivesOnDesktop = false;
        ShowPathbar = true;
        ShowRemovableMediaOnDesktop = true;
        ShowStatusBar = true;
      };
      hitoolbox.AppleFnUsageType = "Do Nothing";
      iCal.CalendarSidebarShown = true;
      magicmouse.MouseButtonMode = "OneButton";
      menuExtraClock = {
        FlashDateSeparators = false;
        ShowAMPM = true;
        ShowDate = 1;
        ShowDayOfWeek = true;
        ShowSeconds = true;
      };
      screencapture = {
        location = "~/Desktop";
        save-selections = false;
        show-thumbnail = false;
        type = "png";
      };
      screensaver = {
        askForPassword = true;
        askForPasswordDelay = 0;
      };
      smb = {
        NetBIOSName = "MAC";
        ServerDescription = "Shun's MacBook M4 Pro Max";
      };
      trackpad = {
        ActuateDetents = true;
        Clicking = true;
        DragLock = false;
        Dragging = true;
        ForceSuppressed = false;
        TrackpadRightClick = true;
        TrackpadPinch = true;
        TrackpadRotate = true;
        TrackpadMomentumScroll = true;
        TrackpadThreeFingerDrag = false;
        TrackpadCornerSecondaryClick = 0;
        TrackpadFourFingerHorizSwipeGesture = 2;
        TrackpadFourFingerPinchGesture = 2;
        TrackpadFourFingerVertSwipeGesture = 2;
        TrackpadThreeFingerHorizSwipeGesture = 2;
        ActuationStrength = 0;
        FirstClickThreshold = 0;
        SecondClickThreshold = 0;
        TrackpadThreeFingerTapGesture = 2;
        TrackpadThreeFingerVertSwipeGesture = 2;
        TrackpadTwoFingerDoubleTapGesture = true;
        TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
      };
    };
    activationScripts.extraActivation.text = builtins.toString (
      if !isRunner && (builtins.getEnv "NIX_OFFLINE" != "1") then
        ''
          softwareupdate --all --install;
        ''
      else
        ''
          echo "Skipping activation scripts for runner";
        ''
    );
  };
}
