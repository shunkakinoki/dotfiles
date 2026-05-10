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
  # Shared SSH key for GitHub authentication (synced from galactica)
  # This is the id_github key from galactica, which is the GitHub-authorized key
  "keys/id_github.age" = {
    file = ../galactica/keys/id_ed25519.age;
    publicKeys = allMachines;
  };

  # GPG key for commit signing (synced from galactica)
  "keys/gpg.age" = {
    file = ../galactica/keys/gpg.age;
    publicKeys = allMachines;
  };
}
