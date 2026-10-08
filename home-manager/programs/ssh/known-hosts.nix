let
  publicKeys = import ../../../named-hosts/pubkeys.nix;
  # Fleet control-plane commands reach kamino hosts by tailnet address, not by
  # name, and OpenSSH looks the key up under whatever it connected to, so each
  # key is pinned under both.
  kaminoAddresses = {
    kamino1 = "100.72.148.9";
    kamino2 = "100.67.227.82";
    kamino3 = "100.67.178.121";
    kamino4 = "100.120.209.125";
    kamino5 = "100.127.59.11";
    kamino6 = "100.65.213.115";
    kamino7 = "100.124.45.106";
    kamino8 = "100.115.11.42";
    kamino9 = "100.113.16.10";
    kamino10 = "100.126.253.87";
  };
  kaminoKnownHosts = builtins.concatStringsSep "\n" (
    builtins.concatMap (
      number:
      let
        name = "kamino${toString number}";
      in
      [
        "${name}.tail950b36.ts.net ${publicKeys.${name}}"
        "${kaminoAddresses.${name}} ${publicKeys.${name}}"
      ]
    ) (builtins.genList (index: index + 1) 10)
  );
in
builtins.readFile ./known_hosts + "\n" + kaminoKnownHosts + "\n"
