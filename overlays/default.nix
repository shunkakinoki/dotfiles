{ inputs }:
[
  inputs.nur.overlays.default
  inputs.neovim-nightly-overlay.overlays.default
  inputs.foundry.overlay
  (_: prev: {
    # Ensure neovim-unwrapped exposes a lua attribute for wrapper consumers (e.g., home-manager)
    # Also disable checks on both neovim and neovim-unwrapped: neovim-nightly-overlay
    # sets them to distinct derivations, and programs.neovim / devenv use pkgs.neovim.
    # The nightly functionaltest suite (e.g. treesitter) is flaky on cache miss.
    neovim-unwrapped =
      (prev.neovim-unwrapped.overrideAttrs (oldAttrs: {
        passthru = (oldAttrs.passthru or { }) // {
          lua = prev.lua5_4;
        };
        doCheck = false;
        doInstallCheck = false;
      }))
      // {
        lua = prev.lua5_4;
      };
    neovim = prev.neovim.overrideAttrs (_: {
      doCheck = false;
      doInstallCheck = false;
    });
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
  inputs.llm-agents.overlays.shared-nixpkgs
  (
    _: prev:
    {
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
    }
    // prev.lib.optionalAttrs (prev ? mise) {
      # mise's Cargo test suite asserts setuid bits survive OCI layer extraction,
      # which the nix build sandbox does not preserve on darwin/linux runners.
      mise = prev.mise.overrideAttrs (_: {
        doCheck = false;
      });
    }
  )
  inputs.noctalia-shell.overlays.default
  (_: prev: {
    moshi-hook = prev.stdenv.mkDerivation rec {
      pname = "moshi-hook";
      version = "0.2.78";
      src = prev.fetchurl {
        url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_${
          if prev.stdenv.isDarwin then "Darwin" else "Linux"
        }_${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "x86_64"}.tar.gz";
        sha256 =
          if prev.stdenv.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "f9b9e2af8d6a2402a94d81afa37757130d07e49481010531761c6a1f6f9d89a5"
          else if prev.stdenv.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "f32282aaf2383960d9f8b37af18d7dd45708b8595b839aeb59b6b2d0b9013d8b"
          else if prev.stdenv.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "7cd1bcdd4f65bad9eca67abfdddb426f897361397fc2fc31975ae3abdec53ce2"
          else
            "f65efb454976679da41e90a2caac365176a940cf43ce6ebc0bdc0015b4609862";
      };
      sourceRoot = ".";
      dontConfigure = true;
      dontBuild = true;
      installPhase = ''
        install -Dm755 moshi-hook $out/bin/moshi-hook
        ln -s moshi-hook $out/bin/moshi
      '';
    };
  })
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
