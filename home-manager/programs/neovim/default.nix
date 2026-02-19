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
  buildTools = if pkgs.stdenv.isDarwin then [ pkgs.gnumake pkgs.clang ] else [ pkgs.gnumake pkgs.gcc ];
  libExt = "so";
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

  home.activation.buildNvimNativePlugins = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${lib.makeBinPath buildTools}:$PATH"
    fzf_dir=""
    for d in ${packDir}/*/opt/telescope-fzf-native.nvim ${packDir}/*/start/telescope-fzf-native.nvim; do
      if [ -d "$d" ]; then
        fzf_dir="$d"
        break
      fi
    done
    if [ -n "$fzf_dir" ] && [ ! -f "$fzf_dir/build/libfzf.${libExt}" ]; then
      echo "Building telescope-fzf-native.nvim in $fzf_dir..."
      $DRY_RUN_CMD make -C "$fzf_dir" clean all
    fi
  '';
}
