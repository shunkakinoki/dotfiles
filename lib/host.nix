{
  # Detect if running on kyber (linux)
  isKyber = builtins.getEnv "HOSTNAME" == "kyber" || builtins.getEnv "HOST" == "kyber";

  # Detect if running on galactica (macOS node)
  isGalactica = builtins.getEnv "HOSTNAME" == "galactica" || builtins.getEnv "HOST" == "galactica";

  # Detect if running on matic (Framework 13)
  isMatic = builtins.getEnv "HOSTNAME" == "matic" || builtins.getEnv "HOST" == "matic";

  # Desktop machines with GUI - default false, override in named-hosts
  isDesktop = false;

  # Install language server packages
  isLSP = true;

  # Get the node name for OpenClaw remote mode
  # Falls back to "unknown" if no hostname is detected
  nodeName =
    if builtins.getEnv "HOSTNAME" == "kyber" || builtins.getEnv "HOST" == "kyber" then
      "kyber"
    else if builtins.getEnv "HOSTNAME" == "galactica" || builtins.getEnv "HOST" == "galactica" then
      "galactica"
    else if builtins.getEnv "HOSTNAME" == "matic" || builtins.getEnv "HOST" == "matic" then
      "matic"
    else
      "unknown";
}
