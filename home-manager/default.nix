{
  config,
  pkgs,
  lib,
  inputs,
  username,
  isRunner ? false,
  ...
}:
let
  hmConfig = import ../config { inherit inputs; };
  modules = import ./modules;
  nix = import ./nix;
  packages = import ./packages { inherit pkgs inputs isRunner; };
  hostIdentityPath = lib.makeBinPath [
    pkgs.inetutils
    pkgs.coreutils
    pkgs.tailscale
    pkgs.jq
  ];
  programs = import ./programs {
    inherit config lib pkgs;
    sources = { };
  };
  services = import ./services {
    inherit
      config
      lib
      pkgs
      inputs
      ;
  };
in
{
  imports =
    hmConfig
    ++ modules
    ++ nix
    ++ programs
    ++ services
    ++ [
      inputs.agenix.homeManagerModules.default
    ]
    ++ lib.optionals (pkgs.stdenv.hostPlatform.isLinux && inputs.host.isDesktop) [
      inputs.handy.homeManagerModules.default
      {
        services.handy = {
          enable = true;
          package = inputs.handy.packages.${pkgs.stdenv.hostPlatform.system}.handy;
        };
      }
    ];

  home.username = username;
  home.homeDirectory = lib.mkIf pkgs.stdenv.hostPlatform.isLinux "/home/${username}";
  home.packages = packages;
  home.stateVersion = "24.11";

  home.activation.verifyHostIdentity =
    lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && inputs.host.nodeName != "unknown")
      (
        config.lib.dag.entryBefore [ "backupExistingFiles" "checkLinkTargets" "writeBoundary" ] ''
          export PATH=${hostIdentityPath}:$PATH
          ${pkgs.bash}/bin/bash ${./activation/check-host-identity.sh} ${lib.escapeShellArg inputs.host.nodeName}
        ''
      );

  # Agents launched by the user manager (T3 Code, Herdr, OpenClaw) never source
  # a login shell, so give them the same session environment. environment.d
  # cannot run command substitutions, so those shell-only values stay behind.
  systemd.user.sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.filterAttrs (_: value: !(lib.hasInfix "$(" (toString value))) config.home.sessionVariables
  );

  # Suppress home-manager manual options.json generation warning.
  manual.manpages.enable = false;

  accounts.email.accounts = {
    Gmail = {
      primary = true;
      flavor = "gmail.com";
      realName = "Shun Kakinoki";
      address = "shunkakinoki@gmail.com";
    };
  };
}
