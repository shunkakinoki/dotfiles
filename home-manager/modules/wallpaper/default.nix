{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.host) isDesktop;
  aerials = {
    earth = pkgs.fetchurl {
      url = "https://sylvan.apple.com/Aerials/2x/Videos/comp_A001_C001_120530_v04_SDR_FINAL_20180706_SDR_4K_HEVC.mov";
      hash = "sha256-ICh/5nst25Z2tJzj0fWtzEhWCCKy2YFId3bgVaXzLxE=";
    };
    greenland = pkgs.fetchurl {
      url = "https://sylvan.apple.com/Aerials/2x/Videos/comp_GL_G002_C002_PSNK_v03_SDR_PS_20180925_SDR_4K_HEVC.mov";
      hash = "sha256-7QYGk7kpixMMSyHImtDmzVmYXNLUOI6fo9IACCbvABs=";
    };
    caribbean = pkgs.fetchurl {
      url = "https://sylvan.apple.com/Aerials/2x/Videos/comp_GMT308_139K_142NC_CARIBBEAN_DAY_v09_SDR_FINAL_22062018_SDR_4K_HEVC.mov";
      hash = "sha256-pUFv341o8tYf2KHBJZbrDrsSjSqw6fQORWYRIgQ7ib8=";
    };
    iss-flare = pkgs.fetchurl {
      url = "https://sylvan.apple.com/Aerials/2x/Videos/comp_A105_C003_0212CT_FLARE_v10_SDR_PS_FINAL_20180711_SDR_4K_HEVC.mov";
      hash = "sha256-7ug1KSdc2lAOacU1Fm/BbAHqpMCkoDGdar2ND/hE9Lk=";
    };
  };
  playlist = pkgs.writeText "aerial-playlist.m3u" (
    lib.concatStringsSep "\n" (lib.attrValues aerials)
  );
in
lib.mkIf (pkgs.stdenv.isLinux && isDesktop) {
  home.file.".local/share/wallpapers/aerial-playlist.m3u".source = playlist;
}
