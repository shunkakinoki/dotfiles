{ config, pkgs, ... }:
{
  programs.fish = {
    enable = true;
    shellInit = ''
      direnv hook fish | source
    '';
    loginShellInit = ''
      fish_add_path -p ~/.local/bin
      fish_add_path -p ~/.bun/bin
      fish_add_path -p ~/.nix-profile/bin
      fish_add_path -p /nix/var/nix/profiles/default/bin
      fish_add_path -p ~/.foundry/bin
      fish_add_path -p /opt/homebrew/bin
      fish_add_path -p /etc/profiles/per-user/${config.home.username}/bin
    '';
    interactiveShellInit = ''
      _hm_load_env_file
      set fish_greeting
      set fish_theme dracula
      fish_add_path -p ~/.local/bin
      fish_add_path -p ~/.bun/bin
      fish_add_path -p ~/.nix-profile/bin
      fish_add_path -p /nix/var/nix/profiles/default/bin
      fish_add_path -p ~/.foundry/bin
      fish_add_path -p /opt/homebrew/bin
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
      # Non-git abbreviations
      c = "clear";
      cat = "bat";
      cc = "claude";
      cs = "claude-squad";
      cx = "codex exec";
      e = "nvim";
      ld = "lazydocker";
      lg = "lazygit";
      ta = "tmux new -A -s default";
      v = "nvim";

      # Function-based abbreviations
      cxe = "_cxe_function";
      clxe = "_clxe_function";
      gco = "_gco_function";
      grco = "_grco_function";
      grcr = "_grcr_function";
      fch = "_fzf_cmd_history --allow-execute";
      fdp = "_fzf_directory_picker --allow-cd --prompt-name Projects ~/";
      ffp = "_fzf_file_picker --allow-open-in-editor --prompt-name Files";
      ffpf = "_fzf_file_picker --allow-open-in-editor --show-hidden-files --prompt-name Files+";
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

  xdg.configFile."fish/themes/dracula.theme" = {
    source = ./dracula.theme;
  };

  xdg.configFile."fish/completions" = {
    source = config.lib.file.mkOutOfStoreSymlink ./completions;
  };

  xdg.configFile."fish/functions" = {
    source = config.lib.file.mkOutOfStoreSymlink ./functions;
  };
}
