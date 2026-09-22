let
  publicKeys = import ../../../named-hosts/pubkeys.nix;
  kaminoHosts = map (number: "kamino${toString number}") [
    1
    2
    3
    4
    5
    6
  ];
  kaminoKnownHosts = builtins.concatStringsSep "\n" (
    map (name: "${name}.tail950b36.ts.net ${publicKeys.${name}}") kaminoHosts
  );
in
builtins.readFile ./known_hosts + "\n" + kaminoKnownHosts + "\n"
