self: super: {
  buildEnv = args: super.buildEnv (args // { ignoreCollisions = true; });
}
