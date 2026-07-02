{ inputs }:
[
  inputs.nur.overlays.default
  inputs.neovim-nightly-overlay.overlays.default
  inputs.foundry.overlay
  (_: prev: {
    # Ensure neovim-unwrapped exposes a lua attribute for wrapper consumers (e.g., home-manager)
    neovim-unwrapped =
      (prev.neovim-unwrapped.overrideAttrs (oldAttrs: {
        passthru = (oldAttrs.passthru or { }) // {
          lua = prev.lua5_4;
        };
      }))
      // {
        lua = prev.lua5_4;
      };
  })
  (_: prev: {
    # Provide non-deprecated alias so upstream modules using pkgs.system don't emit warnings.
    inherit (prev.stdenv.hostPlatform) system;
  })
  (_: prev: {
    # Fix shellspec wrapper script that breaks when called via symlinks
    shellspec = prev.shellspec.overrideAttrs (oldAttrs: {
      postInstall = (oldAttrs.postInstall or "") + ''
        # Replace the wrapper with one that uses an absolute path
        cat > $out/bin/shellspec << EOF
        #!${prev.bash}/bin/sh
        exec "$out/lib/shellspec/shellspec" "\$@"
        EOF
        chmod +x $out/bin/shellspec
      '';
    });
  })
  inputs.llm-agents.overlays.default
  (_: prev: {
    # Upstream grok 0.1.218 fails versionCheckHook because `grok --version`/`--help`
    # do not emit the version string. Disable install check until upstream fixes it.
    # https://github.com/numtide/llm-agents.nix
    llm-agents =
      (prev.llm-agents or { })
      // prev.lib.optionalAttrs (prev.llm-agents ? grok) {
        grok = prev.llm-agents.grok.overrideAttrs (_: {
          doInstallCheck = false;
        });
      }
      // prev.lib.optionalAttrs (prev.llm-agents ? bernstein) {
        # bernstein 2.8.2 requires reportlab<5,>=4.0 but nixpkgs now provides
        # reportlab 5.0.0, failing pythonRuntimeDepsCheckHook.
        # https://github.com/numtide/llm-agents.nix
        bernstein = prev.llm-agents.bernstein.overrideAttrs (_: {
          dontCheckRuntimeDeps = true;
        });
      };
    # mise's Cargo test suite asserts setuid bits survive OCI layer extraction,
    # which the nix build sandbox does not preserve on darwin/linux runners.
    mise = prev.mise.overrideAttrs (_: {
      doCheck = false;
    });
  })
  inputs.noctalia-shell.overlays.default
  (final: prev: {
    nightlyPkgs = import inputs.nixpkgs-nightly {
      inherit (prev) system config;
      overlays = [ ];
    };
    # deno 2.6.10 on nixpkgs-unstable has broken check phase (integration_tests vs integration_test)
    # Use nightly (master) which has the fix and is in the binary cache
    inherit (final.nightlyPkgs)
      deno
      codex
      claude-code
      opencode
      ;
  })
]
