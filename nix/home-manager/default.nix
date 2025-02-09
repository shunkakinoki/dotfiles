# default.nix
{ config, pkgs, lib, inputs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should manage.
  home = {
    username = "shunkakinoki";
    homeDirectory = "/Users/shunkakinoki";

    # This value determines the Home Manager release that your configuration is
    # compatible with.
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

      # Modern CLI tools
      # bottom # System monitor
      # du-dust # Disk usage analyzer
      # procs # Process viewer
      # sd # Find & replace
      # tealdeer # tldr pages
      # zoxide # Smarter cd
      
      # Development environments
      nodejs
      python3
      rustup
      go
      
      # Cloud & Infrastructure
      awscli2
      docker
      kubectl
      
      # System tools
      htop
      bat
      starship # Modern shell prompt
    ];

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      PAGER = "less -R";
      MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    };

    # File associations
    file = {
      # ".zshrc".source = ../zsh/.zshrc;
      # ".gitconfig".source = ../git/.gitconfig;
      # ".config/nvim/init.vim".source = ../neovim/init.vim;
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
    # Modern shell prompt
    starship = {
      enable = true;
      settings = {
        add_newline = false;
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[➜](bold red)";
        };
      };
    };

    # Better cd command
    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    # Git configuration
    git = {
      enable = true;
      userName = "Shun Kakinoki";
      userEmail = "shunkakinoki@gmail.com";
      delta = {
        enable = true;
        options = {
          navigate = true;
          light = false;
          side-by-side = true;
        };
      };
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
        core.editor = "nvim";
        merge.conflictstyle = "diff3";
      };
    };

    # Zsh configuration
    # zsh = {
    #   enable = true;
    #   autosuggestion.enable = true;
    #   enableCompletion = true;
    #   syntaxHighlighting.enable = true;
    #   initExtra = ''
    #     # Additional zsh configurations
    #     bindkey '^[[A' history-substring-search-up
    #     bindkey '^[[B' history-substring-search-down
    #   '';
    #   oh-my-zsh = {
    #     enable = true;
    #     plugins = [ 
    #       "git"
    #       "docker"
    #       "node"
    #       "python"
    #       "rust"
    #       "golang"
    #       "aws"
    #       "kubectl"
    #       "history-substring-search"
    #     ];
    #   };
    # };

    # # Neovim configuration
    # neovim = {
    #   enable = true;
    #   viAlias = true;
    #   vimAlias = true;
    #   plugins = with pkgs.vimPlugins; [
    #     vim-nix
    #     vim-surround
    #     vim-commentary
    #     vim-fugitive
    #     nerdtree
    #     telescope-nvim
    #     nvim-treesitter
    #     lualine-nvim
    #     nvim-lspconfig
    #   ];
    # };

    # # Tmux configuration
    # tmux = {
    #   enable = true;
    #   shortcut = "a";
    #   keyMode = "vi";
    #   customPaneNavigationAndResize = true;
    #   plugins = with pkgs.tmuxPlugins; [
    #     sensible
    #     yank
    #     resurrect
    #     continuum
    #     {
    #       plugin = power-theme;
    #       extraConfig = "set -g @tmux_power_theme 'snow'";
    #     }
    #   ];
    #   extraConfig = ''
    #     # Enable mouse support
    #     set -g mouse on
        
    #     # Start windows and panes at 1, not 0
    #     set -g base-index 1
    #     setw -g pane-base-index 1
        
    #     # Automatically renumber windows
    #     set -g renumber-windows on
    #   '';
    # };

    bat = {
      enable = true;
      config = {
        theme = "TwoDark";
        italic-text = "always";
      };
    };
    
    fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = "fd --type f --hidden --follow --exclude .git";
      defaultOptions = ["--height 40%" "--layout=reverse" "--border"];
    };
  };

  # Additional XDG configurations
  xdg = {
    enable = true;
    configHome = "${config.home.homeDirectory}/.config";
  };
}