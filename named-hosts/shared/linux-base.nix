{
  inputs,
  pkgs,
  username,
  hostname,
  userExtraGroups ? [ ],
  userInitialPassword ? "changemeow",
  stateVersion ? "24.11",
}:
{ lib, ... }:
{
  networking.hostName = hostname;
  networking.networkmanager.enable = true;

  programs.fish.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ]
    ++ userExtraGroups;
    home = "/home/${username}";
    shell = pkgs.fish;
    initialPassword = userInitialPassword;
  };

  security.sudo.wheelNeedsPassword = false;

  nix = {
    channel.enable = false;
    settings = {
      nix-path = lib.mkForce "nixpkgs=/etc/nix/inputs/nixpkgs";
      trusted-users = [
        username
        "@wheel"
        "root"
      ];
    };
  };

  environment.etc."nix/inputs/nixpkgs".source = "${inputs.nixpkgs}";

  system.stateVersion = stateVersion;
}
