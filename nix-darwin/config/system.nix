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
    PATH = "/etc/profiles/per-user/${username}/bin:/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
  };

  system = {
    stateVersion = 4;
    primaryUser = username;
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
