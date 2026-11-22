# One Traces API key shared by every host: make encrypt-key-traces KEY_FILE=traces.env
{
  "keys/traces.env.age".publicKeys = builtins.attrValues (import ../pubkeys.nix);
}
