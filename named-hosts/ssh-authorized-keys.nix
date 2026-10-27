let
  publicKeys = import ./pubkeys.nix;
  keysFor = names: map (name: publicKeys.${name}) names;
  # Every fleet host accepts every other fleet host's key, so fleet commands
  # can run from any host on any other.
  fleetHosts = [
    "beskar"
    "galactica"
    "kyber"
    "matic"
  ]
  ++ map (number: "kamino${toString number}") (builtins.genList (index: index + 1) 7);
  # kamino8-10 run CI jobs, so only kyber accepts their keys.
  ciWorkerHosts = [
    "kamino8"
    "kamino9"
    "kamino10"
  ];
  peersOf = host: keysFor (builtins.filter (name: name != host) fleetHosts);
  galacticaKyberWriterKey = "restrict,command=\"/home/ubuntu/.local/bin/beads-linear-complete-ssh-guard\" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAY5u/jbnetfuqmXFw51/fjUOe96eUt3SDLvaCdqSL14 galactica-kyber-writer-20261027";
in
{
  beskar = peersOf "beskar";
  galactica = peersOf "galactica";
  kyber = peersOf "kyber" ++ keysFor ciWorkerHosts ++ [ galacticaKyberWriterKey ];
  matic = peersOf "matic";
  # One file serves every Kamino host, so it lists the whole fleet.
  kamino = keysFor fleetHosts;
}
