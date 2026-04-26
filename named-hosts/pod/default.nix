# Pod - RunPod GPU cloud host configuration
{
  inputs,
  username ? "root",
  system ? "x86_64-linux",
}:
let
  inherit (inputs) home-manager;
  overlays = import ../../overlays { inherit inputs; };
  nixpkgsConfig = import ../../lib/nixpkgs-config.nix {
    nixpkgsLib = inputs.nixpkgs.lib;
  };
  pkgs = import inputs.nixpkgs {
    inherit system overlays;
    config = nixpkgsConfig;
  };
in
home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  extraSpecialArgs = {
    inherit username pkgs;
    inputs = inputs // {
      host = import ../../lib/host.nix;
    };
  };
  modules = [
    ../../home-manager/default.nix
    (
      { lib, ... }:
      {
        home = {
          inherit username;
          homeDirectory = lib.mkForce (if username == "root" then "/root" else "/home/${username}");
          activation.backupExistingFiles = lib.mkForce {
            before = [ "checkLinkTargets" ];
            after = [ ];
            data = ''
              ${pkgs.bash}/bin/bash "${../../hosts/linux/activate-backup-files.sh}"
            '';
          };
        };
        programs.home-manager.enable = true;

        # NVIDIA/CUDA paths for vLLM and PyTorch on RunPod
        home.sessionVariables = {
          CUDA_HOME = "/usr/local/cuda";
          CUDA_PATH = "/usr/local/cuda";
        };
        programs.fish.interactiveShellInit = lib.mkAfter ''
          # Ensure host NVIDIA/CUDA paths are available
          fish_add_path -g /usr/local/cuda/bin
          set -gx LD_LIBRARY_PATH /usr/local/cuda/lib64 /usr/lib/x86_64-linux-gnu $LD_LIBRARY_PATH
        '';
      }
    )
  ];
}
