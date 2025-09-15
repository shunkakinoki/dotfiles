[
  (final: prev: {
    buildEnv = args: prev.buildEnv (args // { ignoreCollisions = true; });
  })
]
