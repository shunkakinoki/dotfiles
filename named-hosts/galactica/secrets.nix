let
  inherit (import ../pubkeys.nix) galactica kyber matic;
  galacticaHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIql+zLOfvYJFuapmAMQ5yY+yhVMOr9/Of/V0trQ8LrM";
  # All machines that can decrypt shared secrets
  allMachines = [
    galactica
    kyber
    matic
  ];
in
{
  "keys/kyber-writer.age" = {
    file = ./keys/kyber-writer.age;
    publicKeys = [ galacticaHostKey ];
  };

  # SSH key for GitHub authentication (shared with all machines)
  "keys/id_ed25519.age" = {
    file = ./keys/id_ed25519.age;
    publicKeys = allMachines;
  };

  # GPG key (shared with all machines for commit signing)
  "keys/gpg.age" = {
    file = ./keys/gpg.age;
    publicKeys = builtins.attrValues (import ../pubkeys.nix);
  };
}
