{ pkgs, ... }:
{
  home.packages = [ pkgs.tmuxinator ];

  home.file.".config/tmux/session-logger.sh" = {
    executable = true;
    source = ./session-logger.sh;
  };

  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile ./tmux.conf;
    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      tmux-fzf
      resurrect
      continuum
      tmux-sessionx
      tmux-thumbs
      open
      extrakto
    ];
  };
}
