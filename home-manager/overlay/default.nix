# Override Go packages to avoid version conflicts
[
  (final: prev: {
    # Use the latest Go version as default
    go = prev.go_1_25;

    # Wrap go_1_24 to remove conflicting documentation file
    # This allows both versions to coexist without path conflicts
    go_1_24 = prev.symlinkJoin {
      name = "go-1.24-no-conflict";
      paths = [ prev.go_1_24 ];
      postBuild = ''
        # Remove the conflicting documentation file
        rm -f $out/share/go/doc/go_spec.html
      '';
    };
  })
]
