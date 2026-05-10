let
  inherit (import ../pubkeys.nix) galactica kyber matic;
  # All machines that can decrypt shared secrets
  allMachines = [
    galactica
    kyber
    matic
  ];
in
{
  # SSH key for GitHub authentication (shared with all machines)
  "keys/id_ed25519.age" = {
    file = ./keys/id_ed25519.age;
    publicKeys = allMachines;
  };

  # GPG key (shared with all machines for commit signing)
  "keys/gpg.age" = {
    file = ./keys/gpg.age;
    publicKeys = allMachines;
  };
}
