{
  description = "Shun Kakinoki's Nix Configuration";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mk-shell-bin = {
      url = "github:rrbutani/nix-mk-shell-bin";
    };
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      flake-parts,
      treefmt-nix,
      devenv,
      ...
    }@inputs:

    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      imports = [
        treefmt-nix.flakeModule
        devenv.flakeModule
      ];

      flake =
        let
          mkDarwin =
            args:
            let
              darwin-modules = import ./hosts/darwin ({ inherit inputs; } // args);
            in
            inputs.nix-darwin.lib.darwinSystem {
              system = "aarch64-darwin";
              inherit (darwin-modules) specialArgs modules;
            };
        in
        {
          darwinConfigurations = {
            aarch64-darwin = mkDarwin { username = "shunkakinoki"; };
            runner = mkDarwin {
              isRunner = true;
              username = "runner";
            };
            galactica = import ./named-hosts/galactica {
              inherit inputs;
              username = "shunkakinoki";
            };
          };
          nixosConfigurations = {
            x86_64-linux = import ./hosts/nixos {
              inherit inputs;
              username = "shunkakinoki";
            };
            runner = import ./hosts/nixos {
              inherit inputs;
              isRunner = true;
              username = "runner";
            };
          };
          homeConfigurations = {
            "ubuntu@x86_64-linux" = import ./hosts/linux {
              inherit inputs;
              username = "ubuntu";
              system = "x86_64-linux";
            };
            "root@x86_64-linux" = import ./hosts/linux {
              inherit inputs;
              username = "root";
              system = "x86_64-linux";
            };
            "root@aarch64-linux" = import ./hosts/linux {
              inherit inputs;
              username = "root";
              system = "aarch64-linux";
            };
            "runner@x86_64-linux" = import ./hosts/linux {
              inherit inputs;
              isRunner = true;
              username = "runner";
              system = "x86_64-linux";
            };
            "runner@aarch64-linux" = import ./hosts/linux {
              inherit inputs;
              isRunner = true;
              username = "runner";
              system = "aarch64-linux";
            };
          };
        };

      perSystem =
        {
          config,
          system,
          ...
        }:
        let
          inherit (inputs.nixpkgs) lib;
          devenvRoot =
            let
              envRoot = builtins.getEnv "DEVENV_ROOT";
            in
            if envRoot != "" then envRoot else builtins.toString ./.;
          pkgs = import inputs.nixpkgs {
            inherit system;
            config = import ./lib/nixpkgs-config.nix {
              nixpkgsLib = inputs.nixpkgs.lib;
            };
            overlays = (import ./overlays) { inherit inputs; };
          };
          treefmtToml = builtins.fromTOML (builtins.readFile ./treefmt.toml);
          treefmtSettings = lib.recursiveUpdate treefmtToml {
            formatter = {
              nix = (treefmtToml.formatter.nix or { }) // {
                command = lib.getExe pkgs.nixfmt-rfc-style;
              };
              biome = (treefmtToml.formatter.biome or { }) // {
                command = lib.getExe pkgs.biome;
              };
              json = (treefmtToml.formatter.json or { }) // {
                command = lib.getExe pkgs.jsonfmt;
              };
              shell = (treefmtToml.formatter.shell or { }) // {
                command = lib.getExe pkgs.shfmt;
              };
            };
          };
        in
        {
          # Force this attribute so devenv's deprecated helper packages don't surface during flake checks.
          packages = inputs.nixpkgs.lib.mkForce {
            # Use nixpkgs-provided binary to avoid rebuilding cachi.
            devenv-cli = pkgs.devenv;
          };

          devenv.shells.default = (import ./devenv.nix) { inherit pkgs; } // {
            devenv.root = devenvRoot;
          };

          treefmt = {
            projectRootFile = "flake.nix";
            programs = {
              stylua.enable = true;
              taplo.enable = true;
              yamlfmt.enable = true;
            };
            settings = treefmtSettings;
          };
        };
    };
}
