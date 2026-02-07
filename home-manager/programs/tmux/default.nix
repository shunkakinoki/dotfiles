{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile ./tmux.conf;
    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      tmux-fzf
      resurrect
      continuum
      vim-tmux-navigator
      tmux-sessionx
      tmux-thumbs
      open
      extrakto
    ];
  };
}
