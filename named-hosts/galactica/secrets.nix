let
  # Galactica's SSH public key
  galactica = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEKze2jlpV7SyTKA2ezqbumpCiDn+5Sj4z5SxrqfzesX shunkakinoki@gmail.com";
  # Kyber's SSH public key
  kyber = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO0IZtP3KSzY6GVSZ+R+VQYYfu3sEOVaQGDblQxAtwNM ubuntu@kyber";
  # Matic's SSH public key
  matic = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIQqWYSDaaoazVNOrAimCpUxNgaLe9Von237zIoox3E5 skakinoki@matic";
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
