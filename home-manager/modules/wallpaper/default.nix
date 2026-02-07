{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.host) isDesktop;
  wallpaperVideo = pkgs.fetchurl {
    url = "https://sylvan.apple.com/Aerials/2x/Videos/comp_A001_C001_120530_v04_SDR_FINAL_20180706_SDR_4K_HEVC.mov";
    hash = "sha256-ICh/5nst25Z2tJzj0fWtzEhWCCKy2YFId3bgVaXzLxE=";
  };
in
lib.mkIf (pkgs.stdenv.isLinux && isDesktop) {
  home.file.".local/share/wallpapers/aerial.mov".source = wallpaperVideo;
}
