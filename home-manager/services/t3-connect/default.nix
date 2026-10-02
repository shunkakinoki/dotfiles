{ inputs, pkgs, ... }:
let
  inherit (pkgs) lib;
  findPackage =
    if inputs.host.isKyber then
      import ../../../named-hosts/kyber/find.nix { inherit pkgs; }
    else
      pkgs.findutils;
  serveRoutes = import ../../modules/tailscale/routes.nix;
  # Kamino workers are linked publish-only because the relay's managed tunnel
  # quota is too small for the fleet, so clients pair with the T3 server over
  # its tailnet URL instead.
  kaminoT3ServeRoute = {
    name = "t3";
    httpsPort = 443;
    localPort = 3773;
    manager = "t3-service";
  };
  hostServeRoutes =
    serveRoutes.${inputs.host.nodeName}
      or (lib.optional (inputs.host.isKamino or false) kaminoT3ServeRoute);
  t3ServeRoutes = lib.filter (
    route: route.name == "t3" && route.manager == "t3-service"
  ) hostServeRoutes;
  t3ServeRoute = if lib.length t3ServeRoutes == 1 then lib.head t3ServeRoutes else null;
  t3Enabled = pkgs.stdenv.hostPlatform.isLinux && !(inputs.host.t3ConnectDisabled or false);
  # Compile and load native addons with one libc/Node toolchain. Keep the
  # caller's remaining PATH available to provider CLIs in the server.
  toolchain = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    findPackage
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
  # The T3 binary links libatomic from the Nix GCC runtime and node-pty links
  # libstdc++/libgcc. NixOS has no FHS /usr/lib, so its runtime also exposes the
  # desktop library set. Other distros ship those libraries, and a Nix-built copy
  # links a newer glibc than the system, so system binaries and the agents T3
  # spawns abort with "GLIBC_ABI_GNU2_TLS not found". Match the shell policy in
  # home-manager/programs/{bash,zsh,fish} and expose only the GCC runtime there.
  nixosLibraryPath = lib.makeLibraryPath (
    lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.alsa-lib ]
    ++ [
      pkgs.glib.out
      pkgs.libsecret
      pkgs.nspr
      pkgs.nss
      pkgs.stdenv.cc.cc.lib
      pkgs.zlib
    ]
  );
  systemLibraryPath = lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];
  # A systemd `Environment=` value cannot branch on the target, and the host
  # flags are unreliable for generic Linux profiles, so select at runtime. The
  # launcher and the connect oneshot consult this before starting the runtime.
  selectLibraryPath = pkgs.writeShellScript "t3-select-library-path" (
    "export T3_NIXOS_LIBRARY_PATH=${lib.escapeShellArg nixosLibraryPath}\n"
    + "export T3_SYSTEM_LIBRARY_PATH=${lib.escapeShellArg systemLibraryPath}\n"
    + builtins.readFile ./select-library-path.sh
  );
  prepareRuntime = pkgs.writeShellScript "t3-prepare-runtime" (
    "export PATH=${toolchain}:$PATH\n"
    + "export T3_PTY_PROBE=${./pty-probe.cjs}\n"
    + builtins.readFile ./prepare-runtime.sh
  );
  runtimeNpm = pkgs.writeShellScriptBin "npm" (
    "export T3_REAL_NPM=${pkgs.nodejs}/bin/npm\n"
    + "export T3_PREPARE_RUNTIME=${prepareRuntime}\n"
    + builtins.readFile ./runtime-npm.sh
  );
  setLibraryPath = ''export LD_LIBRARY_PATH="$(${selectLibraryPath})"'' + "\n";
  # systemd starts T3 without a login shell, so provider CLIs (OpenCode's
  # `{env:CLIPROXY_API_KEY}`) would otherwise run without the .env secrets.
  launcher = pkgs.writeShellScript "t3-launch-service" (
    "export PATH=${runtimeNpm}/bin:${toolchain}:$PATH\n"
    + setLibraryPath
    + "export T3_PREPARE_RUNTIME=${prepareRuntime}\n"
    + "export HM_PRINT_ENV_FILE=${../../modules/dotenv/print-env-file.sh}\n"
    + ". ${../../modules/dotenv/load-env-file.sh}\n"
    + "_hm_load_env_file\n"
    + builtins.readFile ./launch-service.sh
  );
  runtimeCli = pkgs.writeShellScript "t3-cli" (
    "export PATH=${toolchain}:$PATH\n"
    + setLibraryPath
    + "export T3_SYSTEMD_RUN=${pkgs.systemd}/bin/systemd-run\n"
    + builtins.readFile ./cli.sh
  );
  cliFunction = ''
    export PATH="$HOME/.config/t3/bin:$PATH"
    t3() { ${runtimeCli} "$@"; }
  '';
  connectService = pkgs.writeShellScript "t3-connect-service" (
    setLibraryPath + builtins.readFile ./connect.sh
  );
  shellInstallerPath = ''
    if [ "''${T3_BOOT_SERVICE_UNIT:-}" = t3code.service ]; then
      export PATH=${runtimeNpm}/bin:$PATH
    fi
  '';
in
{
  assertions = lib.optional inputs.host.isKyber {
    assertion = lib.length t3ServeRoutes == 1;
    message = "Kyber must declare exactly one T3 service-owned Tailscale Serve route";
  };

  xdg.configFile."t3/cli.sh" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    source = runtimeCli;
  };

  xdg.configFile."t3/bin/t3" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    source = runtimeCli;
  };
  programs.fish.shellInit = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.mkOrder 2100 "set -gx PATH $HOME/.config/t3/bin $PATH"
  );
  programs.fish.loginShellInit = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.mkOrder 2100 "set -gx PATH $HOME/.config/t3/bin $PATH"
  );

  # The service runtime can advance beyond the globally installed CLI. Always
  # use its bundled CLI so a legacy installer cannot downgrade launcher state.
  # Functions take precedence over Bun's global shims in all login shells.
  programs.fish.functions.t3 = lib.mkIf pkgs.stdenv.hostPlatform.isLinux ''
    command ${runtimeCli} $argv
  '';
  # bashrcExtra runs before Home Manager's noninteractive return, including
  # Bash's SSH startup path, which reads .bashrc instead of BASH_ENV.
  programs.bash.bashrcExtra = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.mkOrder 2100 cliFunction
  );
  programs.zsh.envExtra = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (lib.mkOrder 2100 cliFunction);

  # T3 prefers PATH read from an interactive login shell to its inherited PATH.
  # Run after fnm's shell setup so that hydration retains the scoped installer.
  programs.fish.interactiveShellInit = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.mkOrder 2000 ''
      if test "$T3_BOOT_SERVICE_UNIT" = t3code.service
        set -gx PATH ${runtimeNpm}/bin $PATH
      end
      set -gx PATH $HOME/.config/t3/bin $PATH
    ''
  );
  programs.bash.profileExtra = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.mkOrder 2000 (shellInstallerPath + cliFunction)
  );
  programs.zsh.initContent = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.mkOrder 2000 (shellInstallerPath + cliFunction)
  );

  # T3 owns the main unit. A drop-in survives `t3 service install/update` and
  # prevents the interactive shell's fnm Node from changing the runtime ABI.
  # Agent fleets in sibling units (herdr, roborev) can saturate every core.
  # At the default weight the server's event loop then stalls for seconds,
  # relay and websocket heartbeats lapse, and clients show "reconnecting".
  xdg.configFile."systemd/user/t3code.service.d/native-runtime.conf" = lib.mkIf t3Enabled {
    text = ''
      [Service]
      CPUWeight=1000
      ExecStart=
      ExecStart=${launcher}
      ${lib.optionalString (t3ServeRoute != null) ''
        Environment=T3CODE_TAILSCALE_SERVE=true
        Environment=T3CODE_TAILSCALE_SERVE_PORT=${toString t3ServeRoute.httpsPort}
      ''}
    '';
  };

  # Provider subprocesses inherit T3's cgroup. Bound their reads without
  # freezing the server or throttling other managed user services.
  xdg.configFile."systemd/user/t3code.service.d/read-io.conf" = lib.mkIf inputs.host.isKyber {
    text = ''
      [Service]
      IOAccounting=true
      IOReadBandwidthMax=/ 20M
      IOReadIOPSMax=/ 200
    '';
  };

  systemd.user.services.t3-connect = lib.mkIf t3Enabled {
    Unit = {
      Description = "Keep the T3 remote server ready to accept connections";
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${toolchain}"
        "T3_PREPARE_RUNTIME=${prepareRuntime}"
        "T3_SYSTEMCTL=${pkgs.systemd}/bin/systemctl"
        "T3_ENSURE_SERVICE=${if inputs.host.isKamino or false then "1" else "0"}"
        "XDG_RUNTIME_DIR=%t"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus"
      ];
      Nice = 19;
      IOSchedulingPriority = 7;
      ExecStart = "${pkgs.bash}/bin/bash ${connectService}";
    };
  };

  systemd.user.timers.t3-connect = lib.mkIf t3Enabled {
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
