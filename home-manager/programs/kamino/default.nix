{ pkgs, ... }:
let
  fleet = import ../../../named-hosts/kamino/fleet.nix { };
  inventory = pkgs.writeText "kamino-fleet.json" (builtins.toJSON fleet);
in
{
  programs.ssh.settings = builtins.listToAttrs (
    map (machine: {
      name = machine.name;
      value = {
        HostName = machine.hostname;
        User = machine.user;
      };
    }) fleet.machines
  );

  home.packages = [
    (pkgs.writeShellApplication {
      name = "kamino-fleet";
      runtimeInputs = [
        pkgs.python3
        pkgs.openssh
      ];
      text = ''
        exec python3 ${../../../named-hosts/kamino/fleet.py} --inventory ${inventory} "$@"
      '';
    })
  ];
}
