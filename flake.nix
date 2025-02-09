{
  description = "shunkakinoki's Nix Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Additional useful inputs
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-23.11";
    
    # Add Homebrew support
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager, flake-utils, nixpkgs-stable, nix-homebrew, homebrew-bundle, homebrew-core, homebrew-cask, ... }:
    let
      linuxSystems = [ "x86_64-linux" "aarch64-linux" ];
      darwinSystems = [ "aarch64-darwin" "x86_64-darwin" ];
      
      # Helper function to generate system-specific outputs
      forAllSystems = nixpkgs.lib.genAttrs darwinSystems;

      # Overlays
      overlays = {
        # Add your custom overlays here
      };

      # Nixpkgs configuration
      nixpkgsConfig = {
        allowUnfree = true;
        allowUnsupportedSystem = true;
      };

      # Helper for development shells
      mkDevShell = system: let 
        pkgs = import nixpkgs {
          inherit system;
          config = nixpkgsConfig;
          overlays = builtins.attrValues overlays;
        };
      in {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixpkgs-fmt
            nil # Nix LSP
            statix # Nix static analysis
          ];
        };
      };
    in
    {
      # Development shell for working on this configuration
      devShells = forAllSystems mkDevShell;

      # Darwin Configurations
      darwinConfigurations = {
        "shunkakinoki" = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit inputs; };
          modules = [
            # Base darwin configuration
            ./nix/darwin

            # Home-manager configuration
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.shunkakinoki = import ./nix/home-manager/default.nix;
                extraSpecialArgs = { inherit inputs; };
                backupFileExtension = "backup";
              };
            }

            # Homebrew configuration
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                enable = true;
                user = "shunkakinoki";
                taps = {
                  "homebrew/homebrew-core" = homebrew-core;
                  "homebrew/homebrew-cask" = homebrew-cask;
                  "homebrew/homebrew-bundle" = homebrew-bundle;
                };
                mutableTaps = true;
                autoMigrate = true;
                enableRosetta = true;
              };
            }
          ];
        };

        # New configuration for CI runner
        runner = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit inputs; };
          modules = [
            ./nix/darwin
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.runner = import ./nix/home-manager/default.nix;
                extraSpecialArgs = { inherit inputs; };
                backupFileExtension = "backup";
              };
            }
          ];
        };
      };

      # Home Manager configuration
      homeConfigurations."shunkakinoki" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        modules = [
          ./nix/home-manager/default.nix
        ];
        extraSpecialArgs = { inherit inputs; };
      };

      # Apps for running common commands
      apps.aarch64-darwin = {
        update = {
          type = "app";
          program = toString (nixpkgs.legacyPackages.aarch64-darwin.writeShellScript "update-script" ''
            set -e
            echo "Updating flake..."
            nix flake update
            echo "Updating home-manager..."
            nix run home-manager -- switch --flake .#shunkakinoki
            echo "Updating nix-darwin..."
            nix run nix-darwin -- switch --flake .#shunkakinoki
            echo "Update complete!"
          '');
        };
      };
    };
} 
