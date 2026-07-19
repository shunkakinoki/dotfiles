let
  isHost = name: builtins.getEnv "HOSTNAME" == name || builtins.getEnv "HOST" == name;
  k3sHosts = {
    andor = {
      clusterName = "andor";
      maxPods = 110;
      tailscaleDns = "andor.tail950b36.ts.net";
      tlsSans = [ "andor.tail950b36.ts.net" ];
      workloadProfile = "external-api";
    };
    kyber = {
      clusterName = "kyber";
      maxPods = 300;
      tailscaleDns = "kyber.tail950b36.ts.net";
      tlsSans = [
        "100.72.158.65"
        "kyber.tail950b36.ts.net"
      ];
      workloadProfile = "full-platform";
    };
  };
in
rec {
  # Detect if running on andor (linux)
  isAndor = isHost "andor";

  # Detect if running on kyber (linux)
  isKyber = isHost "kyber";

  # Detect if running on galactica (macOS node)
  isGalactica = isHost "galactica";

  # Detect if running on matic (Framework 13)
  isMatic = isHost "matic";

  # Detect if running on viper (VM)
  isViper = isHost "viper";

  # Independent single-node k3s servers. Workload selection remains GitOps-owned.
  k3sHostConfigs = k3sHosts;
  isK3sServer = isAndor || isKyber;
  k3s =
    if isAndor then
      k3sHosts.andor
    else if isKyber then
      k3sHosts.kyber
    else
      null;

  # Desktop machines with GUI - default false, override in named-hosts
  isDesktop = false;

  # Install language server packages
  isDev = true;

  # Get the node name for OpenClaw remote mode
  # Falls back to "unknown" if no hostname is detected
  nodeName =
    if isAndor then
      "andor"
    else if isKyber then
      "kyber"
    else if isGalactica then
      "galactica"
    else if isMatic then
      "matic"
    else if isViper then
      "viper"
    else
      "unknown";
}
