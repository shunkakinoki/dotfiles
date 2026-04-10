{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "y";
    settings = {
      manager = {
        sort_by = "mtime";
        sort_reverse = true;
        sort_dir_first = true;
      };
    };
  };
}
