# SSH public keys for all machines.
# Single source of truth shared by per-host secrets.nix files and any
# activation script that needs to authorize cross-host access.
{
  galactica = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEKze2jlpV7SyTKA2ezqbumpCiDn+5Sj4z5SxrqfzesX shunkakinoki@gmail.com";
  kyber = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO0IZtP3KSzY6GVSZ+R+VQYYfu3sEOVaQGDblQxAtwNM ubuntu@kyber";
  matic = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOsMGpqklcznrSAH/TiGvcJoHEF4hyf5yiRz9MDjVVUj skakinoki@matic";
}
