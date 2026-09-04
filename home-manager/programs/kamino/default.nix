{ lib, pkgs, ... }:
let
  fleet = import ../../../named-hosts/kamino/fleet.nix { };
  inventory = pkgs.writeText "kamino-fleet.json" (builtins.toJSON fleet);
  shortcuts = lib.concatMap (machine: [
    {
      name = machine.name;
      body = "ssh ${machine.name} $argv";
      description = "SSH to ${machine.name} over Tailscale";
    }
    {
      name = "${machine.name}d";
      body = ''ssh -t ${machine.name} "tmux new-session -A -s desktop"'';
      description = "Attach to ${machine.name} tmux desktop session";
    }
    {
      name = "${machine.name}h";
      body = "herdr --remote ${machine.name} $argv";
      description = "Attach to Herdr on ${machine.name}";
    }
    {
      name = "${machine.name}m";
      body = ''ssh -t ${machine.name} "tmux new-session -A -s mobile"'';
      description = "Attach to ${machine.name} tmux mobile session";
    }
    {
      name = "${machine.name}z";
      body = ''ssh -t ${machine.name} "zellij attach -c desktop"'';
      description = "Attach to ${machine.name} Zellij desktop session";
    }
  ]) fleet.machines;
in
{
  programs.fish = {
    shellAbbrs = builtins.listToAttrs (
      map (shortcut: lib.nameValuePair shortcut.name "_${shortcut.name}_function") shortcuts
    );
    functions = builtins.listToAttrs (
      map (
        shortcut:
        lib.nameValuePair "_${shortcut.name}_function" {
          inherit (shortcut) body description;
        }
      ) shortcuts
    );
  };

  programs.ssh.settings = builtins.listToAttrs (
    map (machine: {
      inherit (machine) name;
      value = {
        HostName = machine.hostname;
        User = machine.user;
        StrictHostKeyChecking = "accept-new";
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
