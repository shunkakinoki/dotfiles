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
      mkEvalCheck "darwin-galactica"
        (import ../named-hosts/galactica {
          inherit inputs;
          username = "shunkakinoki";
        }).system;
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
      mkEvalCheck "nixos-matic"
        (import ../named-hosts/matic {
          inherit inputs;
          username = "shunkakinoki";
        }).config.system.build.toplevel;

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
    // lib.optionalAttrs (system == "x86_64-linux") {
      eval-home-andor =
        mkEvalCheck "home-andor"
          (import ../named-hosts/andor {
            inherit inputs;
            username = "ubuntu";
            system = "x86_64-linux";
          }).activationPackage;
      eval-home-kyber =
        mkEvalCheck "home-kyber"
          (import ../named-hosts/kyber {
            inherit inputs;
            username = "ubuntu";
            system = "x86_64-linux";
          }).activationPackage;
    };
in
darwinChecks // nixosChecks // homeChecks
