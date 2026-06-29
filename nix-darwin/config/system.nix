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
        "com.apple.mouse.scaling" = null;
        "com.apple.sound.beep.sound" = /System/Library/Sounds/Blow.aiff;
      };
      ActivityMonitor = {
        IconType = null;
        OpenMainWindow = true;
        ShowCategory = 100;
        SortColumn = null;
        SortDirection = null;
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
      CustomUserPreferences = {
        "com.apple.controlcenter" = {
          "NSStatusItem VisibleCC Bluetooth" = true;
          "NSStatusItem VisibleCC Clock" = true;
          "NSStatusItem VisibleCC WiFi" = true;
        };
      };
      NSGlobalDomain = {
        AppleEnableMouseSwipeNavigateWithScrolls = null;
        AppleEnableSwipeNavigateWithScrolls = null;
        AppleFontSmoothing = null;
        AppleICUForce24HourTime = true;
        AppleIconAppearanceTheme = null;
        AppleInterfaceStyle = "Dark";
        AppleInterfaceStyleSwitchesAutomatically = true;
        AppleKeyboardUIMode = null;
        AppleMeasurementUnits = null;
        AppleMetricUnits = null;
        ApplePressAndHoldEnabled = null;
        AppleScrollerPagingBehavior = null;
        AppleShowAllExtensions = true;
        AppleShowAllFiles = null;
        AppleShowScrollBars = null;
        AppleSpacesSwitchOnActivate = null;
        AppleTemperatureUnit = null;
        AppleWindowTabbingMode = null;
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = null;
        NSAutomaticInlinePredictionEnabled = null;
        NSAutomaticPeriodSubstitutionEnabled = true;
        NSAutomaticQuoteSubstitutionEnabled = null;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticWindowAnimationsEnabled = null;
        NSDisableAutomaticTermination = null;
        NSDocumentSaveNewDocumentsToCloud = null;
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        NSScrollAnimationEnabled = null;
        NSStatusItemSelectionPadding = null;
        NSStatusItemSpacing = null;
        NSTableViewDefaultSizeMode = null;
        NSTextShowsControlCharacters = null;
        NSUseAnimatedFocusRing = null;
        NSWindowResizeTime = null;
        NSWindowShouldDragOnGesture = null;
        PMPrintingExpandedStateForPrint = true;
        PMPrintingExpandedStateForPrint2 = true;
        _HIHideMenuBar = null;
        "com.apple.keyboard.fnState" = false;
        "com.apple.mouse.tapBehavior" = null;
        "com.apple.sound.beep.feedback" = null;
        "com.apple.sound.beep.volume" = 1.0;
        "com.apple.springing.delay" = 0.5;
        "com.apple.springing.enabled" = true;
        "com.apple.swipescrolldirection" = true;
        "com.apple.trackpad.enableSecondaryClick" = null;
        "com.apple.trackpad.forceClick" = true;
        "com.apple.trackpad.scaling" = 3.0;
        "com.apple.trackpad.trackpadCornerClickBehavior" = null;
      };
      controlcenter = {
        AirDrop = null;
        BatteryShowPercentage = null;
        Bluetooth = true;
        Display = null;
        FocusModes = null;
        NowPlaying = null;
        Sound = null;
      };
      finder = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        FXEnableExtensionChangeWarning = false;
        FXDefaultSearchScope = null;
        FXPreferredViewStyle = "Nlsv";
        FXRemoveOldTrashItems = null;
        NewWindowTarget = "Recents";
        NewWindowTargetPath = null;
        _FXShowPosixPathInTitle = true;
        _FXEnableColumnAutoSizing = null;
        _FXSortFoldersFirst = null;
        _FXSortFoldersFirstOnDesktop = null;
        CreateDesktop = false;
        QuitMenuItem = true;
        ShowExternalHardDrivesOnDesktop = true;
        ShowHardDrivesOnDesktop = false;
        ShowMountedServersOnDesktop = null;
        ShowPathbar = true;
        ShowRemovableMediaOnDesktop = true;
        ShowStatusBar = true;
      };
      hitoolbox.AppleFnUsageType = "Do Nothing";
      iCal = {
        CalendarSidebarShown = true;
        "TimeZone support enabled" = null;
        "first day of week" = null;
      };
      loginwindow = {
        DisableConsoleAccess = null;
        GuestEnabled = null;
        LoginwindowText = null;
        PowerOffDisabledWhileLoggedIn = null;
        RestartDisabled = null;
        RestartDisabledWhileLoggedIn = null;
        SHOWFULLNAME = null;
        ShutDownDisabled = null;
        ShutDownDisabledWhileLoggedIn = null;
        SleepDisabled = null;
        autoLoginUser = null;
      };
      magicmouse.MouseButtonMode = "OneButton";
      menuExtraClock = {
        FlashDateSeparators = false;
        IsAnalog = null;
        Show24Hour = true;
        ShowAMPM = false;
        ShowDate = 1;
        ShowDayOfMonth = null;
        ShowDayOfWeek = true;
        ShowSeconds = true;
      };
      screencapture = {
        disable-shadow = null;
        include-date = null;
        location = "~/Desktop";
        save-selections = false;
        show-thumbnail = false;
        target = "file";
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
      spaces.spans-displays = null;
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
      universalaccess = {
        closeViewScrollWheelToggle = null;
        closeViewZoomFollowsFocus = null;
        mouseDriverCursorSize = null;
        reduceMotion = null;
        reduceTransparency = null;
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
