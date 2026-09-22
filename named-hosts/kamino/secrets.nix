let
  inherit (import ../pubkeys.nix)
    galactica
    kamino1
    kamino2
    kamino3
    kamino4
    kamino5
    kamino6
    ;
  recipients = host: [
    galactica
    host
  ];
in
{
  "keys/agents-prd-kamino1.age".publicKeys = recipients kamino1;
  "keys/agents-prd-kamino2.age".publicKeys = recipients kamino2;
  "keys/agents-prd-kamino3.age".publicKeys = recipients kamino3;
  "keys/agents-prd-kamino4.age".publicKeys = recipients kamino4;
  "keys/agents-prd-kamino5.age".publicKeys = recipients kamino5;
  "keys/agents-prd-kamino6.age".publicKeys = recipients kamino6;
}
