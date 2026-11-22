# One Traces API key shared by every host: make encrypt-key-traces KEY_FILE=traces.env
let
  # Galactica's user key has a passphrase that its unattended agenix agent
  # cannot enter, so Galactica decrypts with its host key instead.
  galacticaHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIql+zLOfvYJFuapmAMQ5yY+yhVMOr9/Of/V0trQ8LrM";
in
{
  "keys/traces.env.age".publicKeys = builtins.attrValues (import ../pubkeys.nix) ++ [ galacticaHost ];
}
