{ pkgs, ... }:
{
  home.packages = with pkgs; [
    ghc
    # haskell-language-server # cache.nixos.org fails to serve it; re-enable once it downloads
  ];
}
