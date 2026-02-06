# Matic secrets - managed by agenix
# To add a new secret:
# 1. Add the secret definition here
# 2. Run: make encrypt-key-matic KEY_FILE=/path/to/secret
let
  # Galactica's SSH public key
  galactica = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEKze2jlpV7SyTKA2ezqbumpCiDn+5Sj4z5SxrqfzesX shunkakinoki@gmail.com";
  # Matic's SSH public key
  matic = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIQqWYSDaaoazVNOrAimCpUxNgaLe9Von237zIoox3E5 skakinoki@matic";
  # All machines that can decrypt shared secrets
  allMachines = [
    galactica
    matic
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
