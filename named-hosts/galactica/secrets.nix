let
  inherit (import ../pubkeys.nix) galactica kyber matic;
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

  # Passphrase-free key galactica presents to the Kamino workers through
  # Crabbox, which runs every transfer under a generated `ssh -F` config that
  # excludes ~/.ssh/config and so can never reach the macOS Keychain. galactica
  # cannot decrypt this itself: its only identity is passphrase-protected and
  # activation is non-interactive. Restore it from kyber or matic, per README.
  "keys/kamino_ci_ed25519.age" = {
    file = ./keys/kamino_ci_ed25519.age;
    publicKeys = allMachines;
  };

  # GPG key (shared with all machines for commit signing)
  "keys/gpg.age" = {
    file = ./keys/gpg.age;
    publicKeys = builtins.attrValues (import ../pubkeys.nix);
  };
}
