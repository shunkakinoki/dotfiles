let
  inherit (import ../pubkeys.nix)
    galactica
    matic
    kyber
    beskar
    ;
in
{
  "login.age".publicKeys = [
    galactica
    matic
    kyber
    beskar
  ];
}
