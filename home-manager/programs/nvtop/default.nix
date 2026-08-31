{ pkgs, ... }:
{
  home.packages = [
    (if pkgs.stdenv.hostPlatform.isDarwin then pkgs.nvtopPackages.apple else pkgs.nvtopPackages.full)
  ];
}
