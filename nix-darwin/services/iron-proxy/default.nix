{
  lib,
  isRunner,
  pkgs,
}:
{ config, ... }:
let
  # "log": pf passes and logs (pflog0) everything the agent user sends outside
  # the proxy. "enforce": the same traffic is rejected.
  mode = "log";
  # Point macOS system HTTP/HTTPS proxy settings at iron-proxy. Requires the
  # CA at /var/lib/iron-proxy/ca.crt to be trusted in the System keychain.
  systemProxy = false;

  agentUser = "shunkakinoki";
  agentUid = 501;
  proxyUser = "iron-proxy";
  proxyId = 450;
  stateDir = "/var/lib/iron-proxy";
  guardStateDir = "/var/db/iron-proxy-guard";
  tunnelPort = 8899;
  captiveWindowSeconds = 600;

  ironProxyConfig = pkgs.writeText "iron-proxy.yaml" (
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

  # Apple's own /etc/pf.conf anchors are kept so macOS features that load
  # rules into com.apple/* keep working. The captive anchor is evaluated
  # first because a quick match in an earlier anchor ends evaluation.
  pfConf = ''
    set skip on lo0
    scrub-anchor "com.apple/*"
    nat-anchor "com.apple/*"
    rdr-anchor "com.apple/*"
    dummynet-anchor "com.apple/*"
    anchor "com.apple/*"
    load anchor "com.apple" from "/etc/pf.anchors/com.apple"
    anchor "ironproxy-captive"
    anchor "ironproxy"
    load anchor "ironproxy" from "/etc/pf.anchors/ironproxy"
  '';

  # Tailnet, LAN, link-local, multicast and Apple (APNs, iCloud) stay direct.
  pfAnchor = ''
    table <ironproxy_direct> const { 100.64.0.0/10, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16, 224.0.0.0/4, 255.255.255.255, 17.0.0.0/8, fe80::/10, ff00::/8, fd00::/8, 2620:149::/32 }
    pass out quick proto { tcp udp } to <ironproxy_direct> user ${toString agentUid}
    ${
      if mode == "enforce" then
        "block return out log quick proto { tcp udp } user ${toString agentUid}"
      else
        "pass out log quick proto { tcp udp } user ${toString agentUid}"
    }
  '';

  proxyBypassDomains = [
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

  guardScript = pkgs.replaceVars ./guard.sh {
    ironProxyBin = lib.getExe pkgs.iron-proxy;
    inherit
      stateDir
      guardStateDir
      proxyUser
      captiveWindowSeconds
      ;
    agentUid = toString agentUid;
    pfConf = "/etc/pf.ironproxy.conf";
    systemProxy = if systemProxy then "1" else "0";
    proxyPort = toString tunnelPort;
    networkServices = lib.concatStringsSep ":" config.networking.knownNetworkServices;
    bypassDomains = lib.concatStringsSep " " proxyBypassDomains;
    caBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  };

  envScript = pkgs.replaceVars ./env.sh {
    inherit stateDir;
    proxyPort = toString tunnelPort;
    noProxy = lib.concatStringsSep "," (map (lib.removePrefix "*") proxyBypassDomains ++ [ "::1" ]);
  };

  bypassScript = pkgs.writeShellApplication {
    name = "iron-proxy-bypass";
    text = builtins.readFile (
      pkgs.replaceVars ./bypass.sh {
        inherit guardStateDir;
        agentUid = toString agentUid;
      }
    );
  };
in
lib.mkIf (!isRunner) {
  assertions = [
    {
      assertion = mode != "enforce" || systemProxy;
      message = "iron-proxy: enforce mode without systemProxy blocks all GUI egress";
    }
    {
      assertion = mode != "enforce" || !(lib.hasInfix "NOPASSWD" config.security.sudo.extraConfig);
      message = "iron-proxy: enforce mode is bypassable while ${agentUser} has NOPASSWD sudo";
    }
  ];

  users = {
    knownUsers = [ proxyUser ];
    knownGroups = [ proxyUser ];
    groups.${proxyUser}.gid = proxyId;
    users.${proxyUser} = {
      uid = proxyId;
      gid = proxyId;
      home = stateDir;
      shell = "/usr/bin/false";
      isHidden = true;
      description = "iron-proxy egress proxy";
    };
  };

  environment.etc = {
    "pf.ironproxy.conf".text = pfConf;
    "pf.anchors/ironproxy".text = pfAnchor;
  };

  environment.systemPackages = [
    pkgs.iron-proxy
    bypassScript
  ];

  launchd.daemons = {
    "com.shunkakinoki.iron-proxy" = {
      serviceConfig = {
        ProgramArguments = [
          (lib.getExe pkgs.iron-proxy)
          "-config"
          "${ironProxyConfig}"
        ];
        UserName = proxyUser;
        GroupName = proxyUser;
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 10;
        StandardOutPath = "/var/log/iron-proxy.log";
        StandardErrorPath = "/var/log/iron-proxy.log";
      };
    };

    # Root-only: agents running as ${agentUser} cannot open a bypass window.
    "com.shunkakinoki.iron-proxy-guard" = {
      serviceConfig = {
        ProgramArguments = [
          "/bin/bash"
          "${guardScript}"
        ];
        RunAtLoad = true;
        StartInterval = 30;
        WatchPaths = [ "/Library/Preferences/SystemConfiguration" ];
        StandardOutPath = "/var/log/iron-proxy-guard.log";
        StandardErrorPath = "/var/log/iron-proxy-guard.log";
      };
    };
  };

  launchd.user.agents.iron-proxy-env = {
    serviceConfig = {
      ProgramArguments = [
        "/bin/bash"
        "${envScript}"
      ];
      RunAtLoad = true;
      StartInterval = 60;
      WatchPaths = [ stateDir ];
      ProcessType = "Background";
    };
  };
}
