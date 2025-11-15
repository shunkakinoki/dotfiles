{
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    # enableFishIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
}
