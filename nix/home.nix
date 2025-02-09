# home.nix
{ config, pkgs, lib, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should manage.
  home = {
    username = "shunkakinoki";
    homeDirectory =
      if pkgs.stdenv.hostPlatform.isDarwin then
        "/Users/shunkakinoki"
      else
        "/home/shunkakinoki";

    # This value determines the Home Manager release that your configuration is
    # compatible with. This helps avoid breakage when a new Home Manager release
    # introduces backwards incompatible changes.
    stateVersion = "23.11";

    packages = with pkgs; [
      # Development tools
      git
      neovim
      zsh
      tmux
      ripgrep
      fd
      fzf
      jq
      tree

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

    # File associations
    file = {
      ".zshrc".source = ../zsh/.zshrc;
      ".gitconfig".source = ../git/.gitconfig;
      ".config/nvim/init.vim".source = ../neovim/init.vim;
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Platform-specific configurations
  home.activation = {
    darwinConfig = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        # macOS specific activation scripts
      ''
    );

    linuxConfig = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        # Linux specific activation scripts
      ''
    );
  };

  # Program configurations
  programs = {
    # Git configuration
    git = {
      enable = true;
      userName = "Shun Kakinoki";
      userEmail = "shunkakinoki@gmail.com";
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
      };
    };

    # Zsh configuration
    zsh = {
      enable = true;
      enableAutosuggestions = true;
      enableCompletion = true;
      syntaxHighlighting.enable = true;
      oh-my-zsh = {
        enable = true;
        plugins = [ "git" "docker" "node" "python" "rust" ];
        theme = "robbyrussell";
      };
    };

    # Neovim configuration
    neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      plugins = with pkgs.vimPlugins; [
        vim-nix
        vim-surround
        vim-commentary
        vim-fugitive
        nerdtree
      ];
    };

    # Tmux configuration
    tmux = {
      enable = true;
      shortcut = "a";
      keyMode = "vi";
      customPaneNavigationAndResize = true;
      plugins = with pkgs.tmuxPlugins; [
        sensible
        yank
        resurrect
      ];
    };

    # Modern alternatives to classic Unix commands
    exa.enable = true; # Modern replacement for ls
    bat.enable = true; # Modern replacement for cat
    fzf.enable = true; # Fuzzy finder
  };

  # Additional XDG configurations
  xdg = {
    enable = true;
    configHome = "${config.home.homeDirectory}/.config";
  };
}
