{
  config,
  isRunner,
  lib,
  pkgs,
  username,
  ...
}:
let
  # "log": nftables accepts everything the agent user sends outside the proxy
  # and kernel-logs (journalctl -k) new connections, rate-limited.
  # "enforce": the same traffic is rejected.
  mode = "log";

  shared = import ../../lib/iron-proxy.nix { inherit pkgs; };
  inherit (shared) proxyUser stateDir;

  resolvConf = config.environment.etc."resolv.conf".text or null;
  nameservers = lib.pipe (if resolvConf == null then "" else resolvConf) [
    (lib.splitString "\n")
    (map (lib.removePrefix "nameserver "))
    (builtins.filter (lib.hasInfix "."))
    (builtins.filter (line: !(lib.hasInfix " " line)))
  ];

  # glibc resolves in-process, so DNS to the configured resolvers leaves as
  # the agent user. systemd-resolved hosts (matic) go through lo instead.
  dnsRule =
    lib.optionalString (nameservers != [ ])
      "ip daddr { ${lib.concatStringsSep ", " nameservers} } meta l4proto { tcp, udp } th dport 53 return";

  # A separate table hooks output alongside whatever the NixOS firewall
  # loads, so it survives firewall reloads and needs no nftables backend
  # switch on hosts where Docker still drives iptables.
  rules = pkgs.writeText "ironproxy.nft" ''
    table inet ironproxy
    delete table inet ironproxy
    table inet ironproxy {
      set direct4 {
        type ipv4_addr
        flags interval
        elements = { ${lib.concatStringsSep ", " shared.directIPv4} }
      }
      set direct6 {
        type ipv6_addr
        flags interval
        elements = { ${lib.concatStringsSep ", " shared.directIPv6} }
      }
      chain output {
        type filter hook output priority 0; policy accept;
        meta skuid != "${username}" return
        oifname "lo" return
        ip daddr @direct4 return
        ip6 daddr @direct6 return
        ${dnsRule}
        ct state new limit rate 20/second burst 50 packets log prefix "iron-proxy-egress: "
        counter ${if mode == "enforce" then "reject with icmpx admin-prohibited" else "accept"}
      }
    }
  '';

  ensureCa = pkgs.writeShellScript "iron-proxy-ensure-ca" ''
    set -eu
    if [ ! -s ${stateDir}/ca.key ]; then
      ${lib.getExe pkgs.iron-proxy} generate-ca -outdir ${stateDir} -name "iron-proxy local CA" -expiry-hours 26280
    fi
    chmod 600 ${stateDir}/ca.key
    chmod 644 ${stateDir}/ca.crt
    cat ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt ${stateDir}/ca.crt >${stateDir}/ca-bundle.crt.tmp
    chmod 644 ${stateDir}/ca-bundle.crt.tmp
    mv -f ${stateDir}/ca-bundle.crt.tmp ${stateDir}/ca-bundle.crt
  '';

  # Never fails the unit: without the marker, sessions simply stay direct.
  # Polls briefly at start; iron-proxy-ready re-checks after that.
  markReady = pkgs.writeShellScript "iron-proxy-mark-ready" ''
    for _ in $(seq 50); do
      if (exec 3<>/dev/tcp/127.0.0.1/${toString shared.tunnelPort}) 2>/dev/null; then
        touch ${stateDir}/env-ready
        exit 0
      fi
      sleep 0.2
    done
    rm -f ${stateDir}/env-ready
  '';
in
lib.mkIf (!isRunner) {
  assertions = [
    {
      assertion = mode != "enforce" || config.security.sudo.wheelNeedsPassword;
      message = "iron-proxy: enforce mode is bypassable while wheel has passwordless sudo";
    }
  ];

  users.users.${proxyUser} = {
    isSystemUser = true;
    uid = shared.proxyId;
    group = proxyUser;
    home = stateDir;
    description = "iron-proxy egress proxy";
  };
  users.groups.${proxyUser}.gid = shared.proxyId;

  environment.systemPackages = [
    pkgs.iron-proxy
    shared.secretsScript
  ];

  # Login shells of the agent user route through the proxy while it listens.
  # The CA is generated at runtime, so clients get it from the state dir
  # rather than security.pki. systemd user services do not read this.
  environment.extraInit = ''
    if [ "$(id -un)" = "${username}" ] && [ -e ${stateDir}/env-ready ]; then
      for _ip_key in HTTPS_PROXY HTTP_PROXY https_proxy http_proxy ALL_PROXY all_proxy; do
        export "$_ip_key=http://127.0.0.1:${toString shared.tunnelPort}"
      done
      export NO_PROXY="${shared.noProxy}" no_proxy="${shared.noProxy}"
      export SSL_CERT_FILE=${stateDir}/ca-bundle.crt REQUESTS_CA_BUNDLE=${stateDir}/ca-bundle.crt CURL_CA_BUNDLE=${stateDir}/ca-bundle.crt
      export NODE_USE_ENV_PROXY=1 NODE_EXTRA_CA_CERTS=${stateDir}/ca.crt
      unset _ip_key
    fi
  '';

  systemd.services.iron-proxy = {
    description = "iron-proxy egress proxy";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      User = proxyUser;
      Group = proxyUser;
      StateDirectory = "iron-proxy";
      StateDirectoryMode = "0755";
      ExecStartPre = [
        "${pkgs.coreutils}/bin/rm -f ${stateDir}/env-ready"
        ensureCa
      ];
      ExecStart = "${lib.getExe pkgs.iron-proxy} -config ${shared.configFile}";
      ExecStartPost = markReady;
      ExecStopPost = "${pkgs.coreutils}/bin/rm -f ${stateDir}/env-ready";
      Restart = "always";
      RestartSec = 10;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };

  # Catches a listener that came up after markReady gave up, and one that
  # died without the unit stopping.
  systemd.services.iron-proxy-ready = {
    description = "Track iron-proxy readiness for agent shells";
    requisite = [ "iron-proxy.service" ];
    after = [ "iron-proxy.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = proxyUser;
      Group = proxyUser;
      ExecStart = markReady;
    };
  };
  systemd.timers.iron-proxy-ready = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "30s";
    };
  };

  systemd.services.iron-proxy-nft = {
    description = "nftables egress rules for the agent user";
    wantedBy = [ "multi-user.target" ];
    after = [ "firewall.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe pkgs.nftables} -f ${rules}";
      ExecStop = "${lib.getExe pkgs.nftables} delete table inet ironproxy";
    };
  };
}
