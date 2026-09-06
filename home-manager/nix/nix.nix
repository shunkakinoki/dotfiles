{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  nix = {
    package = lib.mkDefault pkgs.lixPackageSets.latest.lix;
    # Darwin uses the installer-managed Determinate client and daemon. Adding
    # Lix to activation PATH makes it read unsupported Determinate settings.
    enable = !pkgs.stdenv.hostPlatform.isDarwin;
    registry.nixpkgs.flake = inputs.nixpkgs;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      extra-substituters = [
        "https://cache.numtide.com"
        "https://cloudtide.cachix.org"
        "https://nix-community.cachix.org"
        "https://yazi.cachix.org"
      ];
      extra-trusted-public-keys = [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        "cloudtide.cachix.org-1:9NZ1Mah2+u8cd/CmVffFV23z5uFNpZSrhfgTt5fuN/4="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
      ];
    };
    gc = {
      automatic = !pkgs.stdenv.hostPlatform.isDarwin;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
}
