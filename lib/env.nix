{
  isCI = builtins.getEnv "CI" != "" || builtins.getEnv "IN_DOCKER" == "true";
}
