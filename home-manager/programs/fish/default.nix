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
      end
      direnv hook fish | source
    '';
    loginShellInit = ''
      fish_add_path -p ~/.local/bin
      fish_add_path -p ~/.bun/bin
      fish_add_path -p ~/.nix-profile/bin
      fish_add_path -p /nix/var/nix/profiles/default/bin
      fish_add_path -p ~/.foundry/bin
      fish_add_path -p /opt/homebrew/bin
      fish_add_path -p /opt/homebrew/opt/postgresql@18/bin
      fish_add_path -p /etc/profiles/per-user/${config.home.username}/bin
    '';
    interactiveShellInit = ''
      source ${config.home.homeDirectory}/.config/fish/functions/_hm_load_env_file.fish
      _hm_load_env_file
      set fish_greeting
      set fish_theme dracula
      fish_add_path -p ~/.local/bin
      fish_add_path -p ~/.bun/bin
      fish_add_path -p ~/.nix-profile/bin
      fish_add_path -p /nix/var/nix/profiles/default/bin
      fish_add_path -p ~/.foundry/bin
      fish_add_path -p /opt/homebrew/bin
      fish_add_path -p /opt/homebrew/opt/postgresql@18/bin
      fish_add_path -p /etc/profiles/per-user/${config.home.username}/bin
      set -a fish_complete_path ~/.nix-profile/share/fish/completions/ ~/.nix-profile/share/fish/vendor_completions.d/
      set -x FISH_HISTFILE fish
      fish_vi_key_bindings
    '';
    shellAliases = {
      neofetch = "fastfetch";

      cliproxyapi = "cd ~/.cli-proxy-api && /opt/homebrew/bin/cliproxyapi -config config.yaml";
      ocd = "bun run ${config.home.homeDirectory}/ghq/github.com/shunkakinoki/open-composer/apps/cli/src/index.ts";
    };
    shellAbbrs = {
      cat = "bat";
      e = "nvim";
      g = "git";
      j = "jj";
      lzd = "lazydocker";
      lzg = "lazygit";
      sag = "_ssh_add_github";
      ta = "tmux new -A -s default";
      v = "nvim";

      # Function-based abbreviations
      clxe = "_clxe_function";
      coxe = "_coxe_function";
      coxel = "_coxel_function";
      gco = "_gco_function";
      grco = "_grco_function";
      grcr = "_grcr_function";
      kyber = "_kyber_function";
      kyberd = "_kyberd_function";
      kyberm = "_kyberm_function";
      zdo = "_zdo_function";
      zmo = "_zmo_function";
      fch = "_fzf_cmd_history --allow-execute";
      fdp = "_fzf_directory_picker --allow-cd --prompt-name Projects ~/";
      ffp = "_fzf_file_picker --allow-open-in-editor --prompt-name Files";
      ffpf = "_fzf_file_picker --allow-open-in-editor --show-hidden-files --prompt-name Files+";
      fgb = "_fzf_git_branch";
      fgw = "_fzf_git_worktree";
      fhq = "_fzf_ghq_picker";
      shortcuts = "_fish_shortcuts";
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
    "fish/completions".source = config.lib.file.mkOutOfStoreSymlink ./completions;
  }
  // lib.listToAttrs (
    map
      (name: {
        name = "fish/functions/${name}.fish";
        value.source = ./functions/${name}.fish;
      })
      [
        "_clxe_function"
        "_coxe_function"
        "_coxel_function"
        "_fish_shortcuts"
        "_fzf_cmd_history"
        "_fzf_directory_picker"
        "_fzf_file_picker"
        "_fzf_git_branch"
        "_fzf_git_worktree"
        "_fzf_ghq_picker"
        "_fzf_preview_cmd"
        "_fzf_preview_name"
        "_gco_function"
        "_grco_function"
        "_grcr_function"
        "_hm_load_env_file"
        "_kyber_function"
        "_kyberd_function"
        "_kyberm_function"
        "_zdo_function"
        "_zmo_function"
        "_ssh_add_github"
        "fish_user_key_bindings"
      ]
  );
}
