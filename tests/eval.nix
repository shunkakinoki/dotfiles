{
  pkgs,
  lib,
  inputs,
  system,
}:
let
  isDarwin = lib.hasSuffix "darwin" system;

  # Helper: reconstruct a darwin configuration from hosts/darwin
  mkDarwinConfig =
    args:
    let
      darwin-modules = import ../hosts/darwin ({ inherit inputs; } // args);
    in
    inputs.nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      inherit (darwin-modules) specialArgs modules;
    };

  # Helper: create an eval check derivation
  # Forces evaluation of `expr` via builtins.seq before producing a trivial derivation
  mkEvalCheck =
    name: expr:
    builtins.seq expr (
      pkgs.runCommand "eval-${name}" { } ''
        echo "${name} evaluates successfully"
        touch $out
      ''
    );

  # --- Darwin configurations (aarch64-darwin only) ---
  darwinChecks = lib.optionalAttrs isDarwin {
    eval-darwin-default =
      mkEvalCheck "darwin-default"
        (mkDarwinConfig { username = "shunkakinoki"; }).system;

    eval-darwin-runner =
      mkEvalCheck "darwin-runner"
        (mkDarwinConfig {
          isRunner = true;
          username = "runner";
        }).system;

    eval-darwin-galactica =
      let
        galactica = import ../named-hosts/galactica {
          inherit inputs;
          username = "shunkakinoki";
        };
        activation = galactica.config.system.activationScripts.tailscaleDns.text;
      in
      assert lib.hasInfix "--accept-dns=false" activation;
      assert lib.hasInfix "--accept-routes=true" activation;
      assert lib.hasInfix "--ssh=false" activation;
      mkEvalCheck "darwin-galactica" galactica.system;
  };

  # --- NixOS configurations (x86_64-linux only) ---
  nixosChecks = lib.optionalAttrs (system == "x86_64-linux") {
    eval-nixos-default =
      let
        nixosDefault = import ../hosts/nixos {
          inherit inputs;
          username = "shunkakinoki";
        };
      in
      assert nixosDefault.config.fileSystems."/".device == "/dev/disk/by-label/root";
      assert nixosDefault.config.fileSystems."/boot".device == "/dev/disk/by-partlabel/EFI";
      assert lib.elem "nvme" nixosDefault.config.boot.initrd.availableKernelModules;
      assert builtins.length nixosDefault.config.swapDevices == 1;
      assert (builtins.head nixosDefault.config.swapDevices).device == "/dev/disk/by-label/swap";
      mkEvalCheck "nixos-default" nixosDefault.config.system.build.toplevel;

    eval-nixos-runner =
      let
        nixosRunner = import ../hosts/nixos {
          inherit inputs;
          isRunner = true;
          username = "runner";
        };
      in
      assert nixosRunner.config.fileSystems."/".device == "/dev/sda1";
      mkEvalCheck "nixos-runner" nixosRunner.config.system.build.toplevel;

    eval-nixos-matic =
      let
        matic = import ../named-hosts/matic {
          inherit inputs;
          username = "shunkakinoki";
        };
        cfg = matic.config;
        federationEnvironment =
          cfg.home-manager.users.shunkakinoki.systemd.user.services.dolt-federation-sync.Service.Environment;
      in
      assert
        cfg.services.tailscale.extraSetFlags == [
          "--hostname=matic"
          "--accept-dns=true"
          "--accept-routes=false"
          "--operator=shunkakinoki"
          "--ssh"
        ];
      assert lib.hasInfix "tailscale set" cfg.system.activationScripts.tailscalePreferences.text;
      assert lib.elem "BEADS_FEDERATION_HUB=http://kyber.tail950b36.ts.net:3308" federationEnvironment;
      mkEvalCheck "nixos-matic" cfg.system.build.toplevel;

    eval-nixos-viper =
      mkEvalCheck "nixos-viper"
        (import ../named-hosts/viper {
          inherit inputs;
          username = "shunkakinoki";
        }).config.system.build.toplevel;

    eval-nixos-viper-iso =
      mkEvalCheck "nixos-viper-iso"
        (import ../named-hosts/viper/iso.nix {
          inherit inputs;
          username = "shunkakinoki";
        }).config.system.build.isoImage;
  };

  # --- Home-manager configurations (filtered by matching system) ---
  homeConfigs = {
    "ubuntu-x86_64" = {
      username = "ubuntu";
      system = "x86_64-linux";
    };
    "root-x86_64" = {
      username = "root";
      system = "x86_64-linux";
    };
    "root-aarch64" = {
      username = "root";
      system = "aarch64-linux";
    };
    "runner-x86_64" = {
      isRunner = true;
      username = "runner";
      system = "x86_64-linux";
    };
    "runner-aarch64" = {
      isRunner = true;
      username = "runner";
      system = "aarch64-linux";
    };
  };

  filteredHomeConfigs = lib.filterAttrs (_: args: args.system == system) homeConfigs;

  homeChecks =
    lib.mapAttrs' (
      name: args:
      lib.nameValuePair "eval-home-${name}" (
        mkEvalCheck "home-${name}" (import ../hosts/linux ({ inherit inputs; } // args)).activationPackage
      )
    ) filteredHomeConfigs
    // lib.optionalAttrs (lib.hasSuffix "linux" system) {
      eval-home-linux-rust-linker =
        let
          linux = import ../hosts/linux {
            inherit inputs;
            username = "ubuntu";
            inherit system;
          };
          cfg = linux.config;
          packageNames = map lib.getName cfg.home.packages;
          cargoActivation = cfg.home.activation.installCargoGlobals.data;
          cargoServicePath = builtins.head cfg.systemd.user.services.install-cargo-globals.Service.Environment;
          updaterPath = builtins.head cfg.systemd.user.services.make-updater.Service.Environment;
        in
        assert lib.elem "lld" packageNames;
        assert lib.hasInfix "lld-" cargoActivation;
        assert lib.hasInfix "lld-" cargoServicePath;
        assert lib.hasInfix "lld-" updaterPath;
        mkEvalCheck "home-linux-rust-linker" linux.activationPackage;
    }
    // lib.optionalAttrs (system == "x86_64-linux") {
      eval-home-kamino =
        let
          kamino = import ../named-hosts/kamino { inherit inputs; };
          cfg = kamino.config;
        in
        assert cfg.home.username == "root";
        assert cfg.home.homeDirectory == "/root";
        assert !cfg.nix.enable;
        assert !cfg.nix.gc.automatic;
        assert !(cfg.xdg.configFile ? "nix/nix.conf");
        assert lib.hasInfix "/bin/ssh-keygen" cfg.home.activation.authorizeKaminoSsh.data;
        assert !(cfg.home.activation ? hardenSshd);
        assert !(cfg.home.activation ? setupK3s);
        assert !(cfg.systemd.user.services ? openclaw-gateway);
        assert !(cfg.systemd.user.services ? roborev);
        assert cfg.modules.tailscale.installSystemService;
        assert cfg.modules.tailscale.extraUpArgs == [ ];
        assert cfg.xdg.configFile."kamino/name".text == "kamino\n";
        assert cfg.programs.ssh.settings.kamino.data.User == "root";
        assert cfg.programs.ssh.settings.kamino.data.HostName == "kamino.tail950b36.ts.net";
        assert cfg.programs.ssh.settings.kamino1.data.HostName == "kamino1.tail950b36.ts.net";
        assert cfg.programs.ssh.settings.kamino2.data.User == "root";
        assert cfg.programs.ssh.settings.kamino10.data.HostName == "kamino10.tail950b36.ts.net";
        assert cfg.systemd.user.services.herdr-server.Install.WantedBy == [ "default.target" ];
        assert cfg.systemd.user.services.herdr-server.Unit.X-SwitchMethod == "restart";
        assert cfg.systemd.user.services.herdr-server.Service.EnvironmentFile == [ "-/root/dotfiles/.env" ];
        mkEvalCheck "home-kamino" kamino.activationPackage;
      eval-home-kamino100 =
        let
          kamino = import ../named-hosts/kamino {
            inherit inputs;
            name = "kamino100";
          };
          cfg = kamino.config;
          packageNames = map lib.getName cfg.home.packages;
          activationNames = map (entry: entry.name) (cfg.lib.dag.topoSort cfg.home.activation).result;
          activationPosition =
            name:
            let
              find = index: if builtins.elemAt activationNames index == name then index else find (index + 1);
            in
            find 0;
        in
        assert cfg.home.username == "root";
        assert cfg.home.homeDirectory == "/root";
        assert cfg.xdg.configFile."kamino/name".text == "kamino100\n";
        assert cfg.programs.tmux.enable;
        assert lib.elem "herdr" packageNames;
        assert lib.elem "zellij" packageNames;
        assert cfg.xdg.configFile ? "zellij/config.kdl";
        assert cfg.home.file ? ".config/herdr/config.toml";
        assert cfg.systemd.user.startServices;
        assert activationPosition "checkKaminoIdentity" < activationPosition "writeBoundary";
        assert activationPosition "startKaminoUserManager" < activationPosition "reloadSystemd";
        assert
          activationPosition "prepareKaminoServiceDirectories" < activationPosition "installTailscaleService";
        assert activationPosition "installTailscaleService" < activationPosition "configureKaminoTailscale";
        assert lib.elem "HOST=kamino100" cfg.systemd.user.services.dotfiles-updater.Service.Environment;
        assert cfg.programs.ssh.settings.kamino100.data.User == "root";
        assert cfg.programs.ssh.settings.kamino100.data.HostName == "kamino100.tail950b36.ts.net";
        assert lib.hasInfix "tailscale kamino100" cfg.home.activation.configureKaminoTailscale.data;
        assert lib.hasInfix "--hostname=kamino100" cfg.home.activation.configureKaminoTailscale.data;
        assert lib.hasInfix "--accept-dns=false" cfg.home.activation.configureKaminoTailscale.data;
        assert lib.hasInfix "--ssh=false" cfg.home.activation.configureKaminoTailscale.data;
        mkEvalCheck "home-kamino100" kamino.activationPackage;
      eval-home-andor =
        let
          andor = import ../named-hosts/andor {
            inherit inputs;
            username = "ubuntu";
            system = "x86_64-linux";
          };
        in
        assert
          andor.config.modules.tailscale.extraUpArgs == [
            "--reset"
            "--accept-dns=false"
            "--ssh"
          ];
        mkEvalCheck "home-andor" andor.activationPackage;
      eval-home-kyber =
        let
          kyber = import ../named-hosts/kyber {
            inherit inputs;
            username = "ubuntu";
            system = "x86_64-linux";
          };
          federationEnvironment = kyber.config.systemd.user.services.dolt-federation-sync.Service.Environment;
        in
        assert
          kyber.config.modules.tailscale.extraUpArgs == [
            "--reset"
            "--ssh=false"
            "--accept-dns=false"
            "--advertise-exit-node"
          ];
        assert lib.elem "BEADS_FEDERATION_HUB=http://127.0.0.1:3308" federationEnvironment;
        mkEvalCheck "home-kyber" kyber.activationPackage;
    };
in
darwinChecks // nixosChecks // homeChecks
