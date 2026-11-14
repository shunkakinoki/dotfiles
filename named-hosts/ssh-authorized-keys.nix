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
in
{
  beskar = peersOf "beskar";
  galactica = peersOf "galactica";
  # galactica has no access to kyber.
  kyber =
    keysFor (builtins.filter (name: name != "kyber" && name != "galactica") fleetHosts)
    ++ keysFor ciWorkerHosts;
  matic = peersOf "matic";
  # One file serves every Kamino host, so it lists the whole fleet.
  kamino = keysFor fleetHosts;
}
