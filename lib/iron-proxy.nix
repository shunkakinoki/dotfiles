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
      ];
      log.level = "info";
    }
  );
}
