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
  };

  home.file.".config/nvim/init.lua" = {
    source = nvimInitLua;
    force = true;
  };

  home.file.".config/nvim/lua" = {
    source = ./lua;
    force = true;
  };

  home.activation.copyNvimPackLock = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p "$HOME/.config/nvim"
    $DRY_RUN_CMD cp -f ${nvimPackLockJson} "$HOME/.config/nvim/nvim-pack-lock.json"
    $DRY_RUN_CMD chmod 644 "$HOME/.config/nvim/nvim-pack-lock.json"
  '';

  home.activation.buildNvimNativePlugins = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${lib.makeBinPath buildTools}:$PATH"

    # --- telescope-fzf-native.nvim (C build) ---
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

    # --- fff.nvim (Rust, download prebuilt binary from GitHub releases) ---
    fff_dir=""
    for d in ${packDir}/*/opt/fff.nvim ${packDir}/*/start/fff.nvim; do
      if [ -d "$d" ]; then
        fff_dir="$d"
        break
      fi
    done
    if [ -n "$fff_dir" ]; then
      fff_binary="$fff_dir/target/libfff_nvim.${libExt}"
      if [ ! -f "$fff_binary" ]; then
        echo "Downloading fff.nvim native binary..."
        fff_version=$(git -C "$fff_dir" rev-parse --short HEAD 2>/dev/null || echo "")
        if [ -n "$fff_version" ]; then
          _arch=$(uname -m)
          _ldd=$(ldd --version 2>&1 || echo "")
          if echo "$_ldd" | grep -q musl; then
            _triple="''${_arch}-unknown-linux-musl"
          else
            _triple="''${_arch}-unknown-linux-gnu"
          fi
          mkdir -p "$fff_dir/target"
          echo "Fetching https://github.com/dmtrKovalenko/fff.nvim/releases/download/$fff_version/''${_triple}.${libExt}"
          $DRY_RUN_CMD curl --fail --location --silent --show-error \
            -o "$fff_binary" \
            "https://github.com/dmtrKovalenko/fff.nvim/releases/download/$fff_version/''${_triple}.${libExt}" \
            && echo "fff.nvim binary downloaded successfully" \
            || echo "fff.nvim binary download failed (will fall back to build on first use)"
        else
          echo "fff.nvim: could not determine version, skipping download"
        fi
      fi
    fi

    # --- vscode-diff.nvim (C build via build.sh) ---
    vsd_dir=""
    for d in ${packDir}/*/opt/vscode-diff.nvim ${packDir}/*/start/vscode-diff.nvim; do
      if [ -d "$d" ]; then
        vsd_dir="$d"
        break
      fi
    done
    if [ -n "$vsd_dir" ] && [ ! -f "$vsd_dir/libvscode_diff"*".${libExt}" ] 2>/dev/null; then
      if ls "$vsd_dir"/libvscode_diff*.${libExt} 1>/dev/null 2>&1; then
        : # already built
      else
        echo "Building vscode-diff.nvim native library..."
        $DRY_RUN_CMD bash "$vsd_dir/build.sh" && echo "vscode-diff.nvim built successfully" \
          || echo "vscode-diff.nvim build failed"
      fi
    fi
  '';
}
