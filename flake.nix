{
  description = "Shun Kakinoki's Nix Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
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

      flake = {
        darwinConfigurations = {
          aarch64-darwin = import ./hosts/darwin {
            inherit inputs;
            username = "shunkakinoki";
          };
          runner = import ./hosts/darwin {
            inherit inputs;
            isRunner = true;
            username = "runner";
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
            pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
            lib = inputs.nixpkgs.legacyPackages."x86_64-linux".lib;
          };
          "root@x86_64-linux" = import ./hosts/linux {
            inherit inputs;
            username = "root";
            system = "x86_64-linux";
            pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
            lib = inputs.nixpkgs.legacyPackages."x86_64-linux".lib;
          };
          "root@aarch64-linux" = import ./hosts/linux {
            inherit inputs;
            username = "root";
            system = "aarch64-linux";
            pkgs = inputs.nixpkgs.legacyPackages."aarch64-linux";
            lib = inputs.nixpkgs.legacyPackages."aarch64-linux".lib;
          };
          "runner@x86_64-linux" = import ./hosts/linux {
            inherit inputs;
            isRunner = true;
            username = "runner";
            system = "x86_64-linux";
            pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
            lib = inputs.nixpkgs.legacyPackages."x86_64-linux".lib;
          };
          "runner@aarch64-linux" = import ./hosts/linux {
            inherit inputs;
            isRunner = true;
            username = "runner";
            system = "aarch64-linux";
            pkgs = inputs.nixpkgs.legacyPackages."aarch64-linux";
            lib = inputs.nixpkgs.legacyPackages."aarch64-linux".lib;
          };
        };
      };

      perSystem =
        { ... }:
        {
          treefmt = {
            projectRootFile = "flake.nix";
            programs = {
              actionlint.enable = true;
              biome.enable = true;
              nixfmt.enable = true;
              shfmt.enable = true;
              stylua.enable = true;
              taplo.enable = true;
              yamlfmt.enable = true;
            };
          };
        };
    };
}
