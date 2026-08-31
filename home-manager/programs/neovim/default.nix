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
    if pkgs.stdenv.hostPlatform.isDarwin then
      [
        pkgs.gnumake
        pkgs.clang
      ]
    else
      [
        pkgs.gnumake
        pkgs.gcc
      ];
  libExt = if pkgs.stdenv.hostPlatform.isDarwin then "dylib" else "so";
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

  home.activation.copyNvimPackLock = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate-copy-pack-lock.sh}" "${nvimPackLockJson}"
  '';

  home.activation.buildNvimNativePlugins = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${lib.makeBinPath buildTools}:$PATH"
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate-build-plugins.sh}" "${packDir}" "${libExt}"
  '';
}
