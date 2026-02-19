{
  config,
  lib,
  pkgs,
  ...
}:
let
  nvimInitLua = ./init.lua;
  nvimPackLockJson = ./nvim-pack-lock.json;
in
{
  programs.neovim = {
    enable = true;
    package = pkgs.neovim;
    defaultEditor = true;
    vimAlias = true;
    vimdiffAlias = true;
  };

  home.file.".config/nvim/init.lua" = {
    source = nvimInitLua;
    force = true;
  };

  home.file.".config/nvim/lua" = {
    source = ./lua;
    recursive = true;
    force = true;
  };

  home.activation.copyNvimPackLock = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p "$HOME/.config/nvim"
    $DRY_RUN_CMD cp -f ${nvimPackLockJson} "$HOME/.config/nvim/nvim-pack-lock.json"
    $DRY_RUN_CMD chmod 644 "$HOME/.config/nvim/nvim-pack-lock.json"
  '';
}
