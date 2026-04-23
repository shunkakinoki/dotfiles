{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nodejs
    typescript-language-server
    vscode-langservers-extracted
    vtsls
  ];
}
