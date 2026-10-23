let
  publicKeys = import ./pubkeys.nix;
  keysFor = names: map (name: publicKeys.${name}) names;
  coreHosts = [
    "galactica"
    "kyber"
    "matic"
  ];
  kaminoHosts = map (number: "kamino${toString number}") [
    1
    2
    3
    4
    5
    6
    7
  ];
  # kamino8-10 reach kyber only, for conductor status during lane reconcile.
  conductorOnlyKaminoHosts = map (number: "kamino${toString number}") [
    8
    9
    10
  ];
in
{
  galactica = keysFor kaminoHosts;
  kyber = keysFor (kaminoHosts ++ conductorOnlyKaminoHosts);
  matic = keysFor kaminoHosts;
  kamino = keysFor coreHosts;
  kaminoCiBox = keysFor (coreHosts ++ kaminoHosts);
}
