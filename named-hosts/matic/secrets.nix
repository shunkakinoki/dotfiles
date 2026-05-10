# Matic secrets - synced from galactica via agenix
let
  inherit (import ../pubkeys.nix) galactica matic;
  allMachines = [
    galactica
    matic
  ];
in
{
  "keys/id_github.age" = {
    file = ../galactica/keys/id_ed25519.age;
    publicKeys = allMachines;
  };

  "keys/gpg.age" = {
    file = ../galactica/keys/gpg.age;
    publicKeys = allMachines;
  };
}
