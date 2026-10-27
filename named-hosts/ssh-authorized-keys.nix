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
  galacticaKyberWriterKey = "restrict,command=\"/home/ubuntu/.local/bin/beads-linear-complete-ssh-guard\" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAY5u/jbnetfuqmXFw51/fjUOe96eUt3SDLvaCdqSL14 galactica-kyber-writer-20261027";
in
{
  galactica = keysFor kaminoHosts;
  kyber = keysFor (kaminoHosts ++ conductorOnlyKaminoHosts) ++ [ galacticaKyberWriterKey ];
  matic = keysFor kaminoHosts;
  kamino = keysFor coreHosts;
  kaminoCiBox = keysFor (coreHosts ++ kaminoHosts);
}
