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
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager, flake-utils, nixpkgs-stable, ... }:
    let
      # System types to support
      supportedSystems = [ "aarch64-darwin" "x86_64-darwin" ];
      
      # Helper function to generate system-specific outputs
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      
      # Overlays
      overlays = {
        # Add your custom overlays here
      };
      
      # Nixpkgs configuration
      nixpkgsConfig = {
        allowUnfree = true;
        allowUnsupportedSystem = true;
      };

      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        config = nixpkgsConfig;
        overlays = builtins.attrValues overlays;
      };
    in
    {
      # Apps for running common commands
        update = {
          type = "app";
          program = toString (pkgs.writeShellScript "update-script" ''
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
        update-darwin = {
          type = "app";
          program = toString (pkgs.writeShellScript "update-darwin-script" ''
            set -e
            echo "Updating nix-darwin..."
            nix run nix-darwin -- switch --flake .#shunkakinoki
          '');
        };
        update-home-manager = {
          type = "app";
          program = toString (pkgs.writeShellScript "update-home-manager-script" ''
            set -e
            echo "Updating home-manager..."
            nix run home-manager -- switch --flake .#shunkakinoki
          '');
        };
      };

      darwinConfigurations."shunkakinoki" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [ 
          # Base darwin configuration
          ./nix/darwin
          
          # Home-manager configuration
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              # users.users.shunkakinoki.home = "/Users/shunkakinoki";
              useGlobalPkgs = true;
              useUserPackages = true;
              users.shunkakinoki = import ./nix/home-manager/default.nix;
              extraSpecialArgs = { inherit inputs; };
              backupFileExtension = "backup";
            };
          }
          
          # System-wide configuration
          # {
          #   nixpkgs = { 
          #     inherit overlays;
          #     config = nixpkgsConfig;
          #   };
          # }
        ];
        specialArgs = { inherit inputs; };
      };

      homeConfigurations."shunkakinoki" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ 
          ./nix/home-manager/default.nix
        ];
        extraSpecialArgs = { inherit inputs; };
      };

      # Development shell for working on this configuration
      devShells = forAllSystems (system:
        let 
          pkgs = import nixpkgs {
            inherit system;
            config = nixpkgsConfig;
            overlays = builtins.attrValues overlays;
          };
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixpkgs-fmt
              nil # Nix LSP
              statix # Nix static analysis
            ];
          };
        }
      );
    };
} 
