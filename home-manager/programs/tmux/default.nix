{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile ./tmux.conf;
    plugins = with pkgs.tmuxPlugins; [
      dracula
      sensible
      tmux-fzf
      yank
    ];
  };
}
