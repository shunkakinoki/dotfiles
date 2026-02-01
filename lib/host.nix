{
  # Detect if running on kyber (requires --impure flag, which Makefile already uses)
  isKyber = builtins.getEnv "HOSTNAME" == "kyber" || builtins.getEnv "HOST" == "kyber";

  # Detect if running on galactica (macOS node)
  isGalactica = builtins.getEnv "HOSTNAME" == "galactica" || builtins.getEnv "HOST" == "galactica";

  # Get the node name for OpenClaw remote mode
  # Falls back to "unknown" if no hostname is detected
  nodeName =
    if builtins.getEnv "HOSTNAME" == "kyber" || builtins.getEnv "HOST" == "kyber" then
      "kyber"
    else if builtins.getEnv "HOSTNAME" == "galactica" || builtins.getEnv "HOST" == "galactica" then
      "galactica"
    else
      "unknown";
}
