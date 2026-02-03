{
  # Detect if running on kyber (requires --impure flag, which Makefile already uses)
  isKyber = builtins.getEnv "HOSTNAME" == "kyber" || builtins.getEnv "HOST" == "kyber";

  # Detect if running on galactica (macOS node)
  isGalactica = builtins.getEnv "HOSTNAME" == "galactica" || builtins.getEnv "HOST" == "galactica";

  # Detect if running on matic (Framework 13" AMD AI 300)
  isMatic = builtins.getEnv "HOSTNAME" == "matic" || builtins.getEnv "HOST" == "matic";

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
