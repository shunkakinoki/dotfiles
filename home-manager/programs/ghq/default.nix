{ pkgs, ... }:
{
  home.packages = [
    (pkgs.ghq.override {
      buildGoModule = pkgs.buildGoModule.override {
        go = pkgs.go;
      };
    })
  ];
}
