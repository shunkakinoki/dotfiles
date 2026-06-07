{ pkgs, ... }:
{
  home.file.".config/tmux/session-logger.sh" = {
    executable = true;
    source = ./session-logger.sh;
  };

  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile ./tmux.conf;
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = extrakto;
        extraConfig = "set -g @extrakto_key 'tab'";
      }
      open
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-processes 'btop fish git'
          set -g @resurrect-hook-post-save-all 'd=~/.tmux/resurrect && f="$d/$(readlink "$d/last")" && grep -P "^(pane|window)\twork\t" "$f" > "$f.tmp" && printf "state\twork\n" >> "$f.tmp" && mv "$f.tmp" "$f"'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          # Auto-restore is intentionally off: it fires on every cold tmux
          # server start, racing __tmux_bootstrap_default_session and freezing
          # the freshly-attached client (e.g. on `tpo`). Restore is driven
          # manually by `two`/_two_function for the `work` session only.
          set -g @continuum-restore 'off'
          set -g @continuum-save-interval '3'
          set -g status-right "#[fg=colour250]#{?#{pane_current_command},#{pane_current_command},} #[fg=colour28]| #[fg=colour255]%Y/%m/%d %H:%M:%S #{continuum_status}"
          set -g status-right-length 60
        '';
      }
      sensible
      tmux-fzf
      {
        plugin = tmux-sessionx;
        extraConfig = "set -g @sessionx-bind 'o'";
      }
      {
        plugin = tmux-thumbs;
        extraConfig = "set -g @thumbs-key Space";
      }
      yank
    ];
  };
}
