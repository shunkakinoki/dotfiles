# Override Go packages to use consistent version
[
  (final: prev: {
    # Force all Go packages to use the same version
    go = prev.go_1_24;
    go_1_25 = prev.go_1_24;
  })
]
