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

          # Native libraries for bun-installed packages (e.g. @oh-my-pi/pi-natives, sharp, keytar)
          set -gx LD_LIBRARY_PATH "${pkgs.alsa-lib}/lib" "${pkgs.glib.out}/lib" "${pkgs.libsecret}/lib" "${pkgs.stdenv.cc.cc.lib}/lib" "${pkgs.zlib}/lib" $LD_LIBRARY_PATH
      end

      # Go configuration
      set -gx GOPATH $HOME/go

      # Foundry configuration
      set -gx FOUNDRY_DISABLE_NIGHTLY_WARNING 1

      direnv hook fish | source
    '';
    loginShellInit = ''
      if test -f /opt/homebrew/bin/brew
          eval "$(/opt/homebrew/bin/brew shellenv)"
      end

      # Last line = highest priority (-p -m prepends+moves; last call ends up at front of fish_user_paths)
      fish_add_path -p -m /nix/var/nix/profiles/default/bin
      fish_add_path -p -m ~/.nix-profile/bin
      fish_add_path -p -m /etc/profiles/per-user/${config.home.username}/bin
      fish_add_path -p -m ~/go/bin
      fish_add_path -p -m ~/.cargo/bin
      fish_add_path -p -m ~/.local/bin
      fish_add_path -p -m ~/.local/scripts
      fish_add_path -p -m ~/.bun/bin
      fish_add_path -p -m /opt/homebrew/opt/postgresql@18/bin
      fish_add_path -p -m /opt/homebrew/bin
    '';
    interactiveShellInit = ''
      source ${config.home.homeDirectory}/.config/fish/functions/_hm_load_env_file.fish
      _hm_load_env_file
      set fish_greeting
      set fish_theme dracula

      if test -f /opt/homebrew/bin/brew
          eval "$(/opt/homebrew/bin/brew shellenv)"
      end

      # Last line = highest priority (-p -m prepends+moves; last call ends up at front of fish_user_paths)
      fish_add_path -p -m /nix/var/nix/profiles/default/bin
      fish_add_path -p -m ~/.nix-profile/bin
      fish_add_path -p -m /etc/profiles/per-user/${config.home.username}/bin
      fish_add_path -p -m ~/go/bin
      fish_add_path -p -m ~/.cargo/bin
      fish_add_path -p -m ~/.local/bin
      fish_add_path -p -m ~/.local/scripts
      fish_add_path -p -m ~/.bun/bin
      fish_add_path -p -m /opt/homebrew/opt/postgresql@18/bin
      fish_add_path -p -m /opt/homebrew/bin
      # Worktrunk shell init
      if type -q wt
        wt config shell init fish | source
      end
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
      ompc = "omp commit";
      ompcp = "omp commit --push";
      rm = "gomi";
      v = "nvim";

      # Function-based abbreviations
      cliproxyapi = "_cliproxyapi_function";
      clrc = "_clrc_function";
      cltxe = "_cltxe_function";
      cltxeh = "_cltxeh_function";
      clwrc = "_clwrc_function";
      clwxe = "_clwxe_function";
      clwxeh = "_clwxeh_function";
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
      ocxel = "_ocxel_function";
      ocxeh = "_ocxeh_function";
      ocxelh = "_ocxelh_function";
      ompxe = "_ompxe_function";
      ompxeh = "_ompxeh_function";
      pixe = "_pixe_function";
      pixel = "_pixel_function";
      pixelh = "_pixelh_function";
      pixeh = "_pixeh_function";
      sag = "_ssh_add_github";
      shortcuts = "_fish_shortcuts";
      tdo = "_tdo_function";
      tmo = "_tmo_function";
      tpo = "_tpo_function";
      tsh = "_tsh_function";
      tsk = "_tsk_function";
      tss = "_tss_function";
      tsw = "_tsw_function";
      two = "_two_function";
      zdo = "_zdo_function";
      zmo = "_zmo_function";
      zpo = "_zpo_function";
    };
    plugins = [
      {
        name = "autopair";
        inherit (pkgs.fishPlugins.autopair-fish) src;
      }
      {
        name = "colored-man-pages";
        inherit (pkgs.fishPlugins.colored-man-pages) src;
      }
      {
        name = "done";
        inherit (pkgs.fishPlugins.done) src;
      }
      {
        name = "fzf";
        inherit (pkgs.fishPlugins.fzf) src;
      }
      {
        name = "fzf-fish";
        inherit (pkgs.fishPlugins.fzf-fish) src;
      }
      {
        name = "grc";
        inherit (pkgs.fishPlugins.grc) src;
      }
      {
        name = "puffer";
        inherit (pkgs.fishPlugins.puffer) src;
      }
      {
        name = "sponge";
        inherit (pkgs.fishPlugins.sponge) src;
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
        "_clrc_function"
        "_cltxe_function"
        "_cltxeh_function"
        "_clwrc_function"
        "_clwxe_function"
        "_clwxeh_function"
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
        "_ocxel_function"
        "_ocxeh_function"
        "_ocxelh_function"
        "_ompxe_function"
        "_ompxeh_function"
        "_pixe_function"
        "_pixel_function"
        "_pixelh_function"
        "_pixeh_function"
        "_ssh_add_github"
        "_tdo_function"
        "_tmo_function"
        "_tpo_function"
        "_tsh_function"
        "_tsk_function"
        "_tss_function"
        "_tsw_function"
        "_two_function"
        "_zdo_function"
        "_zmo_function"
        "_zpo_function"
        "fish_user_key_bindings"
      ]
  );
}
