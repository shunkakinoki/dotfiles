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
  };

  outputs =
    {
      flake-parts,
      treefmt-nix,
      ...
    }@inputs:

    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      imports = [ treefmt-nix.flakeModule ];

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
              pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
              lib = inputs.nixpkgs.legacyPackages."x86_64-linux".lib;
            };
            "root@x86_64-linux" = import ./hosts/linux {
              inherit inputs;
              username = "root";
              pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
              lib = inputs.nixpkgs.legacyPackages."x86_64-linux".lib;
            };
            "root@aarch64-linux" = import ./hosts/linux {
              inherit inputs;
              username = "root";
              pkgs = inputs.nixpkgs.legacyPackages."aarch64-linux";
              lib = inputs.nixpkgs.legacyPackages."aarch64-linux".lib;
            };
            "runner@x86_64-linux" = import ./hosts/linux {
              inherit inputs;
              isRunner = true;
              username = "runner";
              pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
              lib = inputs.nixpkgs.legacyPackages."x86_64-linux".lib;
            };
            "runner@aarch64-linux" = import ./hosts/linux {
              inherit inputs;
              isRunner = true;
              username = "runner";
              pkgs = inputs.nixpkgs.legacyPackages."aarch64-linux";
              lib = inputs.nixpkgs.legacyPackages."aarch64-linux".lib;
            };
          };
        };

      perSystem =
        { system, pkgs, ... }:
        {
          treefmt = {
            projectRootFile = "flake.nix";
            programs = {
              biome.enable = true;
              nixfmt.enable = true;
              shfmt.enable = true;
              stylua.enable = true;
              taplo.enable = true;
              jsonfmt.enable = true;
              yamlfmt.enable = true;
            };
          };

          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.nodejs_20
              pkgs.bun
            ];
            shellHook = ''
              echo "Dev shell ready: Node.js + bun available."
            '';
          };
        };
    };
}
