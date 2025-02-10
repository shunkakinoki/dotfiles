{ pkgs }:
{
  fonts.packages = with pkgs; [
    font-fira-mono
    font-roboto-mono
    font-source-code-pro
    font-hack
    font-jetbrains-mono
    nerd-fonts.fira-code
  ];
}
