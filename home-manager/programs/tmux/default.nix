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
      continuum
      extrakto
      open
      resurrect
      sensible
      tmux-fzf
      tmux-sessionx
      tmux-thumbs
      yank
    ];
  };
}
