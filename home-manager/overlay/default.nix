# Override Go packages to use consistent version
[
  (final: prev: {
    # Force all Go versions to use the latest version to avoid conflicts
    go = prev.go_1_25;
    go_1_24 = prev.go_1_25;
    go_1_25 = prev.go_1_25;
  })
]
