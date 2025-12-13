# Kyber secrets - managed by agenix
# To add a new secret:
# 1. Add the secret definition here
# 2. Run: make encrypt-key-kyber KEY_FILE=/path/to/secret
let
  # Galactica's SSH public key
  galactica = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEKze2jlpV7SyTKA2ezqbumpCiDn+5Sj4z5SxrqfzesX shunkakinoki@gmail.com";
  # Kyber's SSH public key
  kyber = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO0IZtP3KSzY6GVSZ+R+VQYYfu3sEOVaQGDblQxAtwNM ubuntu@kyber";
  # All machines that can decrypt shared secrets
  allMachines = [ galactica kyber ];
in
{
  # Tailscale auth key - generate from https://login.tailscale.com/admin/settings/keys
  "keys/tailscale-auth.age" = {
    file = ./keys/tailscale-auth.age;
    publicKeys = [ kyber ];
  };

  # Shared SSH key for GitHub authentication (synced from galactica)
  "keys/id_ed25519.age" = {
    file = ../galactica/keys/id_ed25519.age;
    publicKeys = allMachines;
  };
}
