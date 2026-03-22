{ pkgs, ... }:
{
  home.packages = [
    (if pkgs.stdenv.isDarwin then pkgs.nvtopPackages.apple else pkgs.nvtopPackages.full)
  ];
}
