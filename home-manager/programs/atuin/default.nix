{
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    settings = {
      auto_sync = true;
      sync_frequency = "3m";
      sync_address = "https://api.atuin.sh";
      search_mode = "fuzzy";
    };
  };
}
