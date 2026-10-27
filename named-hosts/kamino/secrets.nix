let
  keys = import ../pubkeys.nix;
in
{
  "keys/agents-prd-kamino2.age".publicKeys = [
    keys.galactica
    keys.kamino2
  ];
}
