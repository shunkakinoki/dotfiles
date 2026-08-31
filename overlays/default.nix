{ inputs }:
[
  inputs.nur.overlays.default
  inputs.neovim-nightly-overlay.overlays.default
  inputs.foundry.overlay
  (_: prev: {
    # Current Foundry nightlies link forge and cast against libudev, which the
    # upstream binary derivation does not yet include in its Linux runtime.
    foundry-bin = prev.foundry-bin.overrideAttrs (old: {
      buildInputs = (old.buildInputs or [ ]) ++ prev.lib.optionals prev.stdenv.isLinux [ prev.udev ];
    });
  })
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
    # Use the immutable GitHub CLI preview commit that adds --attach to issue and PR
    # commands. Remove this override once the feature is released in a tagged version.
    gh = prev.gh.overrideAttrs (_: {
      pname = "gh";
      version = "2.95.0-unstable-20260828";
      src = prev.fetchFromGitHub {
        owner = "cli";
        repo = "cli";
        rev = "40b742f76d68e6b1f472942a6368db4b5d765641";
        hash = "sha256-nGquMOwkEZp6ysFJOw5qa1PqQqw7+WLqpPQiziEAPG0=";
      };
      vendorHash = "sha256-v9h17XD/fyHasgLsHHkGvoV1qITWpwGDJ6MtlvWnN4c=";
      buildPhase = ''
        runHook preBuild
        make GO_LDFLAGS="-s -w -X github.com/cli/cli/v2/internal/build.Date=nixpkgs" GH_VERSION=2.95.0-unstable-20260828 bin/gh manpages
        runHook postBuild
      '';
    });
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
    let
      wrapBuddy = prev.llm-agents.wrapBuddy;
      wrapBuddyBinary = builtins.head wrapBuddy.propagatedBuildInputs;
      fixedWrapBuddy = wrapBuddy.overrideAttrs (_: {
        propagatedBuildInputs = [
          (wrapBuddyBinary.overrideAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              # grep -q exits as soon as it finds the match. With pipefail, the
              # upstream echo producer can then receive SIGPIPE and fail the
              # otherwise-successful install check under loaded CI runners.
              substituteInPlace tests/test.sh \
                --replace-fail 'echo "$output" | grep -q "Hello from patched binary!" ||' \
                'grep -q "Hello from patched binary!" <<< "$output" ||' \
                --replace-fail 'echo "$output" | grep -q "NEEDED_LOADED=yes" ||' \
                'grep -q "NEEDED_LOADED=yes" <<< "$output" ||'
            '';
          }))
        ];
      });
    in
    {
      # Upstream grok 0.1.218 fails versionCheckHook because `grok --version`/`--help`
      # do not emit the version string. Disable install check until upstream fixes it.
      # https://github.com/numtide/llm-agents.nix
      llm-agents =
        (prev.llm-agents or { })
        // prev.lib.optionalAttrs (prev.llm-agents ? grok) {
          grok = prev.llm-agents.grok.overrideAttrs (old: {
            doInstallCheck = false;
            nativeBuildInputs = map (
              input: if (input.outPath or "") == wrapBuddy.outPath then fixedWrapBuddy else input
            ) (old.nativeBuildInputs or [ ]);
          });
          wrapBuddy = fixedWrapBuddy;
        }
        // prev.lib.optionalAttrs (prev.llm-agents ? bernstein) {
          # bernstein 2.8.2 requires reportlab<5,>=4.0 but nixpkgs now provides
          # reportlab 5.0.0, failing pythonRuntimeDepsCheckHook.
          # https://github.com/numtide/llm-agents.nix
          bernstein = prev.llm-agents.bernstein.overrideAttrs (_: {
            dontCheckRuntimeDeps = true;
          });
        }
        // (
          # t3code 0.0.33 pins one pnpm deps hash, but fetchPnpmDeps resolves
          # platform-specific optional packages, so it only reproduces on the
          # system upstream generated it from. Every x86_64-linux build fails on
          # the fixed-output mismatch; other systems keep the upstream hash.
          # https://github.com/numtide/llm-agents.nix
          let
            pnpmDepsHashes = {
              x86_64-linux = "sha256-i/K5bj7CS7PGIX5hfayxAJ7ngNib92w3SDKGXTVWccA=";
            };
            hash = pnpmDepsHashes.${prev.stdenv.hostPlatform.system} or null;
            t3code = prev.llm-agents.t3code.overrideAttrs (
              old:
              prev.lib.optionalAttrs (old ? pnpmDeps) {
                pnpmDeps = old.pnpmDeps.overrideAttrs (_: {
                  outputHash = hash;
                });
              }
            );
          in
          prev.lib.optionalAttrs (hash != null && prev.llm-agents ? t3code) (
            {
              inherit t3code;
            }
            # t3code-desktop is a symlinkJoin over t3code's `desktop` output, so
            # it needs repointing at the repinned build rather than its own fix.
            // prev.lib.optionalAttrs (prev.llm-agents ? t3code-desktop) {
              t3code-desktop = prev.llm-agents.t3code-desktop.overrideAttrs (_: {
                paths = [ t3code.desktop ];
              });
            }
          )
        );
    }
    // prev.lib.optionalAttrs (prev ? mise) {
      # mise's Cargo test suite asserts setuid bits survive OCI layer extraction,
      # which the nix build sandbox does not preserve on darwin/linux runners.
      # mise 2026.8.6 also builds libz-ng-sys from source, whose Rust build
      # script invokes CMake without declaring it in the upstream derivation.
      mise = prev.mise.overrideAttrs (old: {
        doCheck = false;
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.cmake ];
      });
    }
    // prev.lib.optionalAttrs (prev ? vector && prev.stdenv.hostPlatform.isDarwin) {
      # Vector 0.58.0's timing-sensitive check suite is unstable under the
      # Darwin Nix sandbox (exec shutdown, file rotation, and adaptive
      # concurrency tests failed across otherwise-green 2,400+ test runs).
      vector = prev.vector.overrideAttrs (_: {
        doCheck = false;
      });
    }
  )
  inputs.noctalia-shell.overlays.default
  (_: prev: {
    # Keep the Dolt archive-integrity fix independent from the shared nixpkgs
    # pin so storage recovery does not upgrade unrelated host packages.
    dolt = inputs.nixpkgs-dolt.legacyPackages.${prev.system}.dolt;
  })
  (_: prev: {
    blacksmith-testbox-cli = prev.stdenvNoCC.mkDerivation rec {
      pname = "blacksmith-testbox-cli";
      version = "0.4.57";
      src = prev.fetchurl {
        url = "https://clireleases.blacksmith.sh/cli/v${version}/${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }/${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "amd64"}/blacksmith";
        sha256 =
          if prev.stdenv.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "7f60f3b9f8d4d7644d9743f5d962acb3b3dbf675f51676702e5f292e02060bca"
          else if prev.stdenv.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "04c8d261526e23c7791f05b8acec8f02b9d1fe67c35a1adcf28076627327270a"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "607b0f4413e426574527446c7718ea32587d57b24a3ea0749e1ab4138a426584"
          else
            "47281f402ff223f85e5165ea9018cd0281a727f19c69af8121ae4b09658ad313";
      };
      dontUnpack = true;
      installPhase = ''
        install -Dm755 $src $out/bin/blacksmith
      '';
      meta.mainProgram = "blacksmith";
    };

    crabbox = prev.stdenvNoCC.mkDerivation rec {
      pname = "crabbox";
      version = "0.47.0";
      src = prev.fetchurl {
        url = "https://github.com/openclaw/crabbox/releases/download/v${version}/crabbox_${version}_${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }_${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "amd64"}.tar.gz";
        sha256 =
          if prev.stdenv.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "e513ba473be4eaaadf16f88fe030a03e6a11c0b49a088941fcccdbf3a09247ad"
          else if prev.stdenv.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "94a388cd7301c7ba1d7e42d8c55d68c6b9dd55025e79cf247c58d659aa5039d4"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "ef1567083f6bd0d01b2539efdd69ccd205c2642e7d9eefb073d58052e8a7bb91"
          else
            "642995363f7d6c367859e77f80eb66468ef2ed380d1e7ea4ae737f7deeb986d4";
      };
      sourceRoot = ".";
      dontConfigure = true;
      dontBuild = true;
      installPhase = ''
        install -Dm755 crabbox $out/bin/crabbox
        ${prev.lib.optionalString (prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64)
          ''
            install -Dm755 crabbox-apple-vm-helper $out/bin/crabbox-apple-vm-helper
          ''
        }
      '';
      meta.mainProgram = "crabbox";
    };

    moshi-hook = prev.stdenv.mkDerivation rec {
      pname = "moshi-hook";
      version = "0.3.16";
      src = prev.fetchurl {
        url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_${
          if prev.stdenv.hostPlatform.isDarwin then "Darwin" else "Linux"
        }_${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "x86_64"}.tar.gz";
        sha256 =
          if prev.stdenv.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "ee96ff3cebe68648a9631976660afa4a7a247cfa2cc8c030d9d5eca784df5a95"
          else if prev.stdenv.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "8df6d83dcd1aa99c42e7516937f29249f3a8f704d9d9d7eec703fa2287a88666"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "173550c6437e6663dbdf43736fc9cbca2a5af8acf7c3d61b2c3a97c4963cf596"
          else
            "608c8af54a5d7add4e6d58ce2d1b5b3ea0ba536fd8b7e57d947b5f9f244e8311";
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
