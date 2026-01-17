{
  # Detect if running on kyber (requires --impure flag, which Makefile already uses)
  isKyber = builtins.getEnv "HOSTNAME" == "kyber" || builtins.getEnv "HOST" == "kyber";
}
