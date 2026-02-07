{
  config,
  lib,
  pkgs,
  ...
}:
let
  dynamicWallpaper = pkgs.fetchzip {
    url = "https://github.com/zeromhz/jetson/releases/download/dd2019/24hr-Earth-Mac-5K.zip";
    hash = "sha256-tkrgny6Lo2zSh4zgW+UZFGarpJvFhFDYfa3yLuvTqOA=";
    stripRoot = false;
  };
in
lib.mkIf pkgs.stdenv.isLinux {
  home.file.".local/share/wallpapers/dynamic.heic".source =
    "${dynamicWallpaper}/24hr-Earth-5K.heic";
}
