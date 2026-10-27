let
  publicKeys = import ./pubkeys.nix;
  keysFor = names: map (name: publicKeys.${name}) names;
  kaminoHosts = map (number: "kamino${toString number}") [
    1
    2
    3
    4
    5
    6
    7
    8
    9
    10
  ];
  # Every fleet host accepts every other fleet host's key, so fleet commands
  # can run from any host on any other.
  fleetHosts = [
    "beskar"
    "galactica"
    "kyber"
    "matic"
  ]
  ++ kaminoHosts;
  peersOf = host: keysFor (builtins.filter (name: name != host) fleetHosts);
  galacticaKyberWriterKey = "restrict,command=\"/home/ubuntu/.local/bin/beads-linear-complete-ssh-guard\" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAY5u/jbnetfuqmXFw51/fjUOe96eUt3SDLvaCdqSL14 galactica-kyber-writer-20261027";
in
{
  beskar = peersOf "beskar";
  galactica = peersOf "galactica";
  kyber = peersOf "kyber" ++ [ galacticaKyberWriterKey ];
  matic = peersOf "matic";
  # One file serves every Kamino host, so it lists the whole fleet.
  kamino = keysFor fleetHosts;
}
