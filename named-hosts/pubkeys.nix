# SSH public keys for all machines.
# Single source of truth shared by per-host secrets.nix files and any
# activation script that needs to authorize cross-host access.
{
  galactica = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEKze2jlpV7SyTKA2ezqbumpCiDn+5Sj4z5SxrqfzesX shunkakinoki@gmail.com";
  kyber = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICbJMYUWpV2mQhfRnKWLaxRATS7+yvE7u2IYXic6/rIZ ubuntu@kyber";
  galactica-ci = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN/GeyNvgm5sUvO2rB74dLBLFMI/o5onhtbgg6toXGSH galactica-ci";
  matic = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOsMGpqklcznrSAH/TiGvcJoHEF4hyf5yiRz9MDjVVUj skakinoki@matic";
  kamino1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJnhdnehXGjNR+zRORaap4JYCwnRJtUgKgkTLbZ5x+1I root@kamino1";
  kamino2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA3VU0CIet9SStRUdhVKR3SFxGwK9fAyRiX6WIOts6TD root@kamino2";
  kamino3 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH9Vi2pvLR8j52bHJlZ3ghT1n+c5QugN3TQuqBIHJCOG root@kamino3";
  kamino4 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGXNZvPW1xedam57pTusOs1Pwsfbcs6OiAweb7f7TGr4 root@kamino4";
}
