let
  # Galactica's SSH public key
  galactica = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEKze2jlpV7SyTKA2ezqbumpCiDn+5Sj4z5SxrqfzesX shunkakinoki@gmail.com";
  # Kyber's SSH public key
  kyber = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO0IZtP3KSzY6GVSZ+R+VQYYfu3sEOVaQGDblQxAtwNM ubuntu@kyber";
  # All machines that can decrypt shared secrets
  allMachines = [
    galactica
    kyber
  ];
in
{
  # Shared SSH key for GitHub authentication (accessible on all machines)
  # This is ~/.ssh/id_github on galactica, the GitHub CLI-authorized key
  "keys/id_github.age" = {
    file = ./keys/id_github.age;
    publicKeys = allMachines;
  };
  # GPG key (shared with all machines for commit signing)
  "keys/gpg.age" = {
    file = ./keys/gpg.age;
    publicKeys = allMachines;
  };
}
