# home.nix
{ config, pkgs, lib, ... }:

{
  home = {
    username = "shunkakinoki";
    homeDirectory =
      if pkgs.stdenv.hostPlatform.isDarwin then
        "/Users/shunkakinoki"
      else
        "/home/shunkakinoki";

    stateVersion = "23.11";

    packages = with pkgs; [
      # Development tools
      git
      github-cli
      neovim
      zsh
      tmux
      ripgrep
      fd
      fzf
      jq
      tree
      nixpkgs-fmt

      # Language-specific tools
      nodejs
      python3
      rustup

      # System tools
      htop
      bat
      exa
      delta
    ];

    # ... rest of the configuration ...
  };
}
