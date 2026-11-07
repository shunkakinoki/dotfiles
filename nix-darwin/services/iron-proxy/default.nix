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
  # Point macOS system HTTP/HTTPS proxy settings at iron-proxy while the proxy
  # listens and its CA is trusted in the System keychain.
  systemProxy = true;

  shared = import ../../../lib/iron-proxy.nix { inherit pkgs; };
  inherit (shared)
    proxyUser
    proxyId
    stateDir
    tunnelPort
    ;
  ironProxyConfig = shared.configFile;

  agentUid = 501;
  guardStateDir = "/var/db/iron-proxy-guard";
  captiveWindowSeconds = 600;

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

  # Apple (APNs, iCloud) also stays direct on macOS.
  pfAnchor = ''
    table <ironproxy_direct> const { ${
      lib.concatStringsSep ", " (
        shared.directIPv4 ++ [ "17.0.0.0/8" ] ++ shared.directIPv6 ++ [ "2620:149::/32" ]
      )
    } }
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
      message = "iron-proxy: enforce mode is bypassable while security.sudo.extraConfig grants NOPASSWD";
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

    # Root-only: agents running as the agent user cannot open a bypass window.
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
