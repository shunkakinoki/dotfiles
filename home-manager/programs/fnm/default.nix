{ pkgs }:
{
  home.packages = with pkgs; [ fnm ];

  xdg.configFile."fish/conf.d/fnm.fish".text = ''
    fnm env --use-on-cd --shell fish | source
  '';
}
