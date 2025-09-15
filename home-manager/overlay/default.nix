[
  (final: prev: {
    go = super.go_1_25;
    buildEnv = args: prev.buildEnv (args // { ignoreCollisions = true; });
  })
]
