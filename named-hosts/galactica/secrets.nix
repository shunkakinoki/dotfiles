let
  # Galactica's SSH public key
  galactica = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEKze2jlpV7SyTKA2ezqbumpCiDn+5Sj4z5SxrqfzesX shunkakinoki@gmail.com";
  # Kyber's SSH public key
  kyber = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO0IZtP3KSzY6GVSZ+R+VQYYfu3sEOVaQGDblQxAtwNM ubuntu@kyber";
  # All machines that can decrypt shared secrets
  allMachines = [ galactica kyber ];
in
{
  # Shared SSH key for GitHub authentication (accessible on all machines)
  "keys/id_ed25519.age" = {
    file = ./keys/id_ed25519.age;
    publicKeys = allMachines;
  };
  # GPG key (galactica only)
  "keys/gpg.age" = {
    file = ./keys/gpg.age;
    publicKeys = [ galactica ];
  };
}
