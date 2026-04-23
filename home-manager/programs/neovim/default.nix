{
  config,
  lib,
  pkgs,
  ...
}:
let
  nvimInitLua = ./init.lua;
  nvimPackLockJson = ./nvim-pack-lock.json;
  packDir = "$HOME/.local/share/nvim/site/pack";
  buildTools =
    if pkgs.stdenv.isDarwin then
      [
        pkgs.gnumake
        pkgs.clang
      ]
    else
      [
        pkgs.gnumake
        pkgs.gcc
      ];
  libExt = "so";
in
{
  programs.neovim = {
    enable = true;
    package = pkgs.neovim;
    defaultEditor = true;
    vimAlias = true;
    vimdiffAlias = true;
    withRuby = false;
    withPython3 = false;
    initLua = builtins.readFile nvimInitLua;
  };

  xdg.configFile."nvim/init.lua".force = true;

  home.file.".config/nvim/lua" = {
    source = ./lua;
    force = true;
  };

  home.activation.copyNvimPackLock = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate-copy-pack-lock.sh}" "${nvimPackLockJson}"
  '';

  home.activation.buildNvimNativePlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${lib.makeBinPath buildTools}:$PATH"
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate-build-plugins.sh}" "${packDir}" "${libExt}"
  '';
}
