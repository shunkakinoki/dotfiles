{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.fish = {
    enable = true;
    shellInit = ''
      # Set XDG_RUNTIME_DIR on Linux for consistent socket paths (e.g., zellij)
      if test (uname) = "Linux"
          set -gx XDG_RUNTIME_DIR /run/user/(id -u)

          # OpenSSL for cargo builds (rust crates like openssl-sys)
          set -gx PKG_CONFIG_PATH "${pkgs.openssl.dev}/lib/pkgconfig" $PKG_CONFIG_PATH
          set -gx OPENSSL_DIR "${pkgs.openssl.dev}"
          set -gx OPENSSL_LIB_DIR "${pkgs.openssl.out}/lib"
          set -gx OPENSSL_INCLUDE_DIR "${pkgs.openssl.dev}/include"
      end

      # Go configuration
      set -gx GOPATH $HOME/go

      direnv hook fish | source

      # Worktrunk shell init
      wt config shell init fish | source
    '';
    loginShellInit = ''
      if test -f /opt/homebrew/bin/brew
          eval "$(/opt/homebrew/bin/brew shellenv)"
      end

      fish_add_path -p ~/.local/bin
      fish_add_path -p ~/.bun/bin
      fish_add_path -p ~/.cargo/bin
      fish_add_path -p ~/.nix-profile/bin
      fish_add_path -p ~/go/bin
      fish_add_path -p /nix/var/nix/profiles/default/bin
      fish_add_path -p /opt/homebrew/bin
      fish_add_path -p /opt/homebrew/opt/postgresql@18/bin
      fish_add_path -p /etc/profiles/per-user/${config.home.username}/bin
    '';
    interactiveShellInit = ''
      source ${config.home.homeDirectory}/.config/fish/functions/_hm_load_env_file.fish
      _hm_load_env_file
      set fish_greeting
      set fish_theme dracula

      if test -f /opt/homebrew/bin/brew
          eval "$(/opt/homebrew/bin/brew shellenv)"
      end

      fish_add_path -p ~/.local/bin
      fish_add_path -p ~/.bun/bin
      fish_add_path -p ~/.cargo/bin
      fish_add_path -p ~/.nix-profile/bin
      fish_add_path -p ~/go/bin
      fish_add_path -p /nix/var/nix/profiles/default/bin
      fish_add_path -p /opt/homebrew/bin
      fish_add_path -p /opt/homebrew/opt/postgresql@18/bin
      fish_add_path -p /etc/profiles/per-user/${config.home.username}/bin
      set -a fish_complete_path ~/.nix-profile/share/fish/completions/ ~/.nix-profile/share/fish/vendor_completions.d/
      set -x FISH_HISTFILE fish
      fish_vi_key_bindings
    '';
    shellAliases = {
      neofetch = "fastfetch";
      ocd = "bun run ${config.home.homeDirectory}/ghq/github.com/shunkakinoki/open-composer/apps/cli/src/index.ts";
    };
    shellAbbrs = {
      cat = "bat";
      e = "nvim";
      g = "git";
      j = "jj";
      lzd = "lazydocker";
      lzg = "lazygit";
      ta = "tmux new -A -s default";
      v = "nvim";

      # Function-based abbreviations
      cliproxyapi = "_cliproxyapi_function";
      clxe = "_clxe_function";
      clxeh = "_clxeh_function";
      coxe = "_coxe_function";
      coxeh = "_coxeh_function";
      coxel = "_coxel_function";
      coxelh = "_coxelh_function";
      dev = "_dev_function";
      fch = "_fzf_chrome_history";
      fdp = "_fzf_directory_picker --allow-cd --prompt-name Projects ~/";
      ffp = "_fzf_file_picker --allow-open-in-editor --prompt-name Files";
      ffpf = "_fzf_file_picker --allow-open-in-editor --show-hidden-files --prompt-name Files+";
      fgb = "_fzf_git_branch";
      fgw = "_fzf_git_worktree";
      fhq = "_fzf_ghq_picker";
      fpc = "_fzf_preview_cmd";
      fpn = "_fzf_preview_name";
      fsh = "_fzf_shell_history --allow-execute";
      gco = "_gco_function";
      grco = "_grco_function";
      grcr = "_grcr_function";
      hme = "_hm_load_env_file";
      kyber = "_kyber_function";
      kyberd = "_kyberd_function";
      kyberm = "_kyberm_function";
      ocxe = "_ocxe_function";
      ocxeh = "_ocxeh_function";
      pixe = "_pixe_function";
      pixeh = "_pixeh_function";
      sag = "_ssh_add_github";
      shortcuts = "_fish_shortcuts";
      zdo = "_zdo_function";
      zmo = "_zmo_function";
      zpo = "_zpo_function";
    };
    plugins = [
      {
        name = "autopair";
        src = pkgs.fishPlugins.autopair-fish.src;
      }
      {
        name = "colored-man-pages";
        src = pkgs.fishPlugins.colored-man-pages.src;
      }
      {
        name = "done";
        src = pkgs.fishPlugins.done.src;
      }
      {
        name = "fzf";
        src = pkgs.fishPlugins.fzf.src;
      }
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
      {
        name = "grc";
        src = pkgs.fishPlugins.grc.src;
      }
      {
        name = "puffer";
        src = pkgs.fishPlugins.puffer.src;
      }
      {
        name = "sponge";
        src = pkgs.fishPlugins.sponge.src;
      }
    ];
  };

  xdg.configFile = {
    "fish/themes/dracula.theme".source = ./dracula.theme;
    "fish/completions".source = ./completions;
  }
  // lib.listToAttrs (
    map
      (name: {
        name = "fish/functions/${name}.fish";
        value.source = ./functions/${name}.fish;
      })
      [
        "_cliproxyapi_function"
        "_clxe_function"
        "_clxeh_function"
        "_coxe_function"
        "_coxeh_function"
        "_coxel_function"
        "_coxelh_function"
        "_dev_function"
        "_fish_shortcuts"
        "_fzf_chrome_history"
        "_fzf_directory_picker"
        "_fzf_file_picker"
        "_fzf_ghq_picker"
        "_fzf_git_branch"
        "_fzf_git_worktree"
        "_fzf_preview_cmd"
        "_fzf_preview_name"
        "_fzf_shell_history"
        "_gco_function"
        "_grco_function"
        "_grcr_function"
        "_hm_load_env_file"
        "_kyber_function"
        "_kyberd_function"
        "_kyberm_function"
        "_ocxe_function"
        "_ocxeh_function"
        "_pixe_function"
        "_pixeh_function"
        "_ssh_add_github"
        "_zdo_function"
        "_zmo_function"
        "_zpo_function"
        "fish_user_key_bindings"
      ]
  );
}
