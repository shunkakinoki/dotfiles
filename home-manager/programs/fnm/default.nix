{ pkgs }:
{
  home.packages = with pkgs; [ fnm ];

  xdg.configFile."fish/conf.d/fnm.fish".text = builtins.toString ''
    fnm env --use-on-cd --shell fish | source
  '';
}
