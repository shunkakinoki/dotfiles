# Kyber secrets - managed by agenix
# To add a new secret:
# 1. Add the secret definition here
# 2. Run: make encrypt-key-kyber KEY_FILE=/path/to/secret
let
  inherit (import ../pubkeys.nix) galactica kyber;
  # All machines that can decrypt shared secrets
  allMachines = [
    galactica
    kyber
  ];
in
{
  # Shared GitHub deploy key (ciphertext: galactica/keys/id_ed25519.age).
  # Prefer per-host least-privilege deploy keys when rotating credentials.
  "keys/id_github.age" = {
    file = ../galactica/keys/id_ed25519.age;
    publicKeys = allMachines;
  };

  # Shared GPG signing key (synced from galactica). Same blast-radius note as above.
  "keys/gpg.age" = {
    file = ../galactica/keys/gpg.age;
    publicKeys = allMachines;
  };
}
