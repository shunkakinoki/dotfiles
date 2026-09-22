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
  ];
in
{
  galactica = keysFor kaminoHosts;
  kyber = keysFor kaminoHosts;
  matic = keysFor kaminoHosts;
  kamino = keysFor coreHosts;
}
