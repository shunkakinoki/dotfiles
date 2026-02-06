# Matic secrets - synced from galactica via agenix
let
  galactica = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEKze2jlpV7SyTKA2ezqbumpCiDn+5Sj4z5SxrqfzesX shunkakinoki@gmail.com";
  matic = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIQqWYSDaaoazVNOrAimCpUxNgaLe9Von237zIoox3E5 skakinoki@matic";
  allMachines = [
    galactica
    matic
  ];
in
{
  "keys/id_github.age" = {
    file = ../galactica/keys/id_ed25519.age;
    publicKeys = allMachines;
  };

  "keys/gpg.age" = {
    file = ../galactica/keys/gpg.age;
    publicKeys = allMachines;
  };
}
