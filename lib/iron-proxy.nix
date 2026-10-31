{ pkgs }:
rec {
  stateDir = "/var/lib/iron-proxy";
  tunnelPort = 8899;
  proxyUser = "iron-proxy";
  proxyId = 450;

  # Tailnet, LAN, link-local and multicast stay direct for the agent user.
  directIPv4 = [
    "100.64.0.0/10"
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "169.254.0.0/16"
    "224.0.0.0/4"
    "255.255.255.255"
  ];
  directIPv6 = [
    "fe80::/10"
    "ff00::/8"
    "fd00::/8"
  ];

  bypassDomains = [
    "localhost"
    "127.0.0.1"
    "*.local"
    "*.ts.net"
    "169.254.0.0/16"
    "100.64.0.0/10"
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
  ];
  noProxy = pkgs.lib.concatStringsSep "," (
    map (pkgs.lib.removePrefix "*") bypassDomains ++ [ "::1" ]
  );

  # Doppler secrets the proxy swaps in: once synced, agent shells only see
  # "iron-proxy-swap-<name>" and the proxy replaces it on requests to hosts.
  swapSecrets = [
    {
      name = "OPENROUTER_API_KEY";
      hosts = [ "openrouter.ai" ];
    }
  ];
  # Outside stateDir, which the proxy user owns on NixOS, so root never writes
  # into a directory the proxy could plant symlinks in.
  secretsDir = "/var/lib/iron-proxy-secrets";

  secretsScript = pkgs.writeShellApplication {
    name = "iron-proxy-secrets";
    runtimeInputs = [ pkgs.doppler ];
    text = builtins.readFile (
      pkgs.replaceVars ./iron-proxy-secrets.sh {
        inherit secretsDir proxyUser;
        names = pkgs.lib.concatMapStringsSep " " (s: s.name) swapSecrets;
      }
    );
  };

  configFile = pkgs.writeText "iron-proxy.yaml" (
    builtins.toJSON {
      dns.enabled = false;
      proxy = {
        http_listen = "127.0.0.1:18080";
        https_listen = "127.0.0.1:18443";
        tunnel_listen = "127.0.0.1:${toString tunnelPort}";
      };
      tls = {
        mode = "mitm";
        ca_cert = "${stateDir}/ca.crt";
        ca_key = "${stateDir}/ca.key";
      };
      transforms = [
        {
          name = "allowlist";
          config.domains = [ "*" ];
        }
        {
          name = "secrets";
          config.secrets = map (s: {
            # Read lazily, so the proxy starts before the first sync and picks
            # up rotations within the ttl.
            source = {
              type = "file";
              path = "${secretsDir}/${s.name}";
              ttl = "5m";
            };
            replace = {
              proxy_value = "iron-proxy-swap-${s.name}";
              match_headers = s.headers or [ "Authorization" ];
            };
            rules = map (host: { inherit host; }) s.hosts;
          }) swapSecrets;
        }
      ];
      log.level = "info";
    }
  );
}
