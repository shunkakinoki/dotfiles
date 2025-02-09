let
  nix-daemon = import ./nix-daemon;
in
{
  imports = [
    nix-daemon
  ];
}
