let
  keys = import ../pubkeys.nix;
  hosts = [
    "kyber"
    "matic"
    "beskar"
    "kamino1"
    "kamino2"
    "kamino3"
    "kamino4"
    "kamino5"
    "kamino6"
  ];
in
builtins.listToAttrs (
  builtins.map (host: {
    name = "keys/${host}.age";
    value.publicKeys = [
      keys.galactica
      keys.${host}
    ];
  }) hosts
)
