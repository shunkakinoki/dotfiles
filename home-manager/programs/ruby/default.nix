{ pkgs, ... }:
{
  home.packages = with pkgs; [
    ruby
    rubyPackages.ruby-lsp
  ];
}
