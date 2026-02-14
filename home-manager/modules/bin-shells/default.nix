{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
{
  config = lib.mkIf isLinux {
    home.activation.binShells = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      SUDO_CMD=""
      if command -v sudo >/dev/null 2>&1; then
        SUDO_CMD="sudo"
      elif [ -x /run/wrappers/bin/sudo ]; then
        SUDO_CMD="/run/wrappers/bin/sudo"
      elif [ -x /usr/bin/sudo ]; then
        SUDO_CMD="/usr/bin/sudo"
      elif [ "$(id -u)" -ne 0 ]; then
        echo "Creating /bin shell symlinks requires root privileges, but sudo is not available." >&2
        exit 1
      fi

      run_root_cmd() {
        if [ -n "$SUDO_CMD" ]; then
          ''${DRY_RUN_CMD:-} "$SUDO_CMD" "$@"
        else
          ''${DRY_RUN_CMD:-} "$@"
        fi
      }

      run_root_cmd mkdir -p /bin
      run_root_cmd ln -sf ${pkgs.bash}/bin/bash /bin/bash
      run_root_cmd ln -sf ${pkgs.fish}/bin/fish /bin/fish
      run_root_cmd ln -sf ${pkgs.zsh}/bin/zsh /bin/zsh
    '';
  };
}
