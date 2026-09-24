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
  # Fleet commands reach workers by tailnet address (`tailscale ip -4`), so a
  # hostname-only pin still fails host-key verification on a caller that never
  # trusted the address by hand.
  kaminoTailnetAddresses = {
    kamino5 = "100.127.59.11";
    kamino6 = "100.65.213.115";
  };
  kaminoKnownHosts = builtins.concatStringsSep "\n" (
    map (name: "${name}.tail950b36.ts.net ${publicKeys.${name}}") kaminoHosts
    ++ map (name: "${kaminoTailnetAddresses.${name}} ${publicKeys.${name}}") (
      builtins.attrNames kaminoTailnetAddresses
    )
  );
in
builtins.readFile ./known_hosts + "\n" + kaminoKnownHosts + "\n"
