{ pkgs, ... }:
let
  inherit (pkgs) lib;
  # Compile and load native addons with one libc/Node toolchain. Keep the
  # caller's remaining PATH available to provider CLIs in the server.
  toolchain = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.findutils
    pkgs.gawk
    pkgs.gcc
    pkgs.gnugrep
    pkgs.gnumake
    pkgs.gnused
    pkgs.nodejs
    pkgs.python3
    pkgs.util-linux
    pkgs.which
  ];
  prepareRuntime = pkgs.writeShellScript "t3-prepare-runtime" ''
    export PATH=${toolchain}:$PATH
    export T3_PTY_PROBE=${./pty-probe.cjs}
    ${builtins.readFile ./prepare-runtime.sh}
  '';
  runtimeNpm = pkgs.writeShellScriptBin "npm" ''
    export T3_REAL_NPM=${pkgs.nodejs}/bin/npm
    export T3_PREPARE_RUNTIME=${prepareRuntime}
    ${builtins.readFile ./runtime-npm.sh}
  '';
  launcher = pkgs.writeShellScript "t3-launch-service" ''
    export PATH=${runtimeNpm}/bin:${toolchain}:$PATH
    export T3_PREPARE_RUNTIME=${prepareRuntime}
    ${builtins.readFile ./launch-service.sh}
  '';
  shellInstallerPath = ''
    if [ "''${T3_BOOT_SERVICE_UNIT:-}" = t3code.service ]; then
      export PATH=${runtimeNpm}/bin:$PATH
    fi
  '';
in
{
  # T3 prefers PATH read from an interactive login shell to its inherited PATH.
  # Run after fnm's shell setup so that hydration retains the scoped installer.
  programs.fish.interactiveShellInit = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.mkOrder 2000 ''
      if test "$T3_BOOT_SERVICE_UNIT" = t3code.service
        set -gx PATH ${runtimeNpm}/bin $PATH
      end
    ''
  );
  programs.bash.profileExtra = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.mkOrder 2000 shellInstallerPath
  );
  programs.zsh.initContent = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.mkOrder 2000 shellInstallerPath
  );

  # T3 owns the main unit. A drop-in survives `t3 service install/update` and
  # prevents the interactive shell's fnm Node from changing the runtime ABI.
  xdg.configFile."systemd/user/t3code.service.d/native-runtime.conf" =
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux
      {
        text = ''
          [Service]
          ExecStart=
          ExecStart=${launcher}
        '';
      };

  systemd.user.services.t3-connect = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "Keep the T3 remote server ready to accept connections";
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${toolchain}"
        "T3_PREPARE_RUNTIME=${prepareRuntime}"
      ];
      Nice = 19;
      IOSchedulingPriority = 7;
      ExecStart = "${pkgs.bash}/bin/bash ${./connect.sh}";
    };
  };

  systemd.user.timers.t3-connect = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "Timer to keep the T3 remote server ready to accept connections";
    };
    Timer = {
      OnBootSec = "2m";
      OnUnitActiveSec = "30m";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
