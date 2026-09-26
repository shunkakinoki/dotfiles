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
  # Fleet tooling reaches Kamino hosts by tailnet IP, so each address needs the
  # same pinned key as its DNS name or strict host key checking rejects it.
  kaminoAddresses = {
    kamino1 = "100.72.148.9";
    kamino2 = "100.67.227.82";
    kamino3 = "100.67.178.121";
    kamino4 = "100.120.209.125";
    kamino5 = "100.127.59.11";
    kamino6 = "100.65.213.115";
  };
  kaminoKnownHosts = builtins.concatStringsSep "\n" (
    builtins.concatMap (name: [
      "${name}.tail950b36.ts.net ${publicKeys.${name}}"
      "${kaminoAddresses.${name}} ${publicKeys.${name}}"
    ]) kaminoHosts
  );
in
builtins.readFile ./known_hosts + "\n" + kaminoKnownHosts + "\n"
