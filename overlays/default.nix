{ inputs }:
[
  inputs.nur.overlays.default
  inputs.neovim-nightly-overlay.overlays.default
  inputs.foundry.overlay
  (_: prev: {
    # Current Foundry nightlies link forge and cast against libudev, which the
    # upstream binary derivation does not yet include in its Linux runtime.
    foundry-bin = prev.foundry-bin.overrideAttrs (old: {
      # Upstream still evaluates deprecated stdenv.isLinux in this list.
      nativeBuildInputs =
        with prev;
        [
          pkg-config
          openssl
          xz
          makeWrapper
          installShellFiles
        ]
        ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
      buildInputs =
        (old.buildInputs or [ ]) ++ prev.lib.optionals prev.stdenv.hostPlatform.isLinux [ prev.udev ];
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
    # The orchestration repo pins `bun@1.4.2` and its bootstrap
    # (`scripts/orchestration-bootstrap.ts`) refuses to run without
    # `process.execve`, which the locked nixpkgs-unstable bun (1.3.13) lacks.
    # Every fleet lane shells out to `$HOME/.bun/bin/bun`, so a stale bun fails
    # `beads:verify` and lane dispatch fleet-wide. Pin the release the repo
    # declares; the derivation only installs the released binary.
    bun = prev.bun.overrideAttrs (
      finalAttrs: old: {
        version = "1.4.2";
        __intentionallyOverridingVersion = true;
        passthru = old.passthru // {
          sources = {
            "aarch64-darwin" = prev.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}/bun-darwin-aarch64.zip";
              hash = "sha256-kJh6OhbX21VtiGrD1VHnttPt8KHPQ6yu1iLoZ2vh0S8=";
            };
            "aarch64-linux" = prev.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}/bun-linux-aarch64.zip";
              hash = "sha256-VDKLvC2cjgyfiSxUTWbFeoO4QTnjSQnl7oF1jxrI/ac=";
            };
            "x86_64-linux" = prev.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}/bun-linux-x64-baseline.zip";
              hash = "sha256-xngEDxT+BEDrg503y9DOTAUaMtpygGrJfeamqra/co8=";
            };
          };
        };
      }
    );
  })
  (_: prev: {
    # Use the first tagged release that includes --attach on issue and PR commands.
    # gh's go.mod requires Go 1.27, newer than the pinned nixpkgs default.
    gh = (prev.gh.override { buildGoModule = prev.buildGo127Module; }).overrideAttrs (_: {
      pname = "gh";
      version = "2.101.0";
      src = prev.fetchFromGitHub {
        owner = "cli";
        repo = "cli";
        rev = "0cf1092493af067646fc5f3db9421c6a6ec9c938";
        hash = "sha256-EoKF2m5sZP+uQ5AVOKkFqSCACfkeUc7vnH8PHWCO6FE=";
      };
      vendorHash = "sha256-4KYQBgMNc/sI0mbcXSfJ7A/77VAS6NM8TOzQ3w7AlK8=";
      buildPhase = ''
        runHook preBuild
        make GO_LDFLAGS="-s -w -X github.com/cli/cli/v2/internal/build.Date=nixpkgs" GH_VERSION=2.101.0 bin/gh manpages
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
      linuxGrokOverrides =
        prev.lib.optionalAttrs
          (prev.stdenv.hostPlatform.isLinux && prev.llm-agents ? grok && prev.llm-agents ? wrapBuddy)
          (
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
              # wrap-buddy-hook is Linux-only; keep its fix off Darwin evaluation.
              grok = prev.llm-agents.grok.overrideAttrs (old: {
                doInstallCheck = false;
                nativeBuildInputs = map (
                  input: if (input.outPath or "") == wrapBuddy.outPath then fixedWrapBuddy else input
                ) (old.nativeBuildInputs or [ ]);
              });
              wrapBuddy = fixedWrapBuddy;
            }
          );
    in
    {
      # Upstream grok 0.1.218 fails versionCheckHook because `grok --version`/`--help`
      # do not emit the version string. Disable install check until upstream fixes it.
      # https://github.com/numtide/llm-agents.nix
      llm-agents =
        (prev.llm-agents or { })
        // {
          # Keep every managed client and server on the same released protocol.
          # The upstream recipe retains native Linux/Darwin build dependencies.
          herdr = prev.llm-agents.herdr.overrideAttrs (
            finalAttrs: _: {
              version = "0.9.0";
              src = prev.fetchFromGitHub {
                owner = "herdrdev";
                repo = "herdr";
                tag = "v${finalAttrs.version}";
                hash = "sha256-SUYF4bbaYwNgoe498VoCUzuLPcjBLQXR0o0DWjjoSnI=";
              };
              cargoDeps = prev.rustPlatform.fetchCargoVendor {
                inherit (finalAttrs) src;
                name = "herdr-${finalAttrs.version}-vendor";
                hash = "sha256-CW/SF/cAPDv47gS5B7XbVZEE6LC9F1a2I1TLTJ4AWdw=";
              };
            }
          );
        }
        // linuxGrokOverrides
        // prev.lib.optionalAttrs (prev.llm-agents ? bernstein) {
          # bernstein 2.8.2 requires reportlab<5,>=4.0 but nixpkgs now provides
          # reportlab 5.0.0, failing pythonRuntimeDepsCheckHook.
          # https://github.com/numtide/llm-agents.nix
          bernstein = prev.llm-agents.bernstein.overrideAttrs (_: {
            dontCheckRuntimeDeps = true;
          });
        }
        // (
          # t3code 0.0.40 pins one pnpm deps hash, but fetchPnpmDeps resolves
          # platform-specific optional packages, so it only reproduces on the
          # system upstream generated it from. Every x86_64-linux build fails on
          # the fixed-output mismatch; other systems keep the upstream hash.
          # https://github.com/numtide/llm-agents.nix
          let
            pnpmDepsHashes = {
              x86_64-linux = "sha256-+UsoURSM4VP+CgF1fWROBEB85EuH+iJJM/xDPFigCKk=";
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
  inputs.beads.overlays.default
  (_: prev: {
    # Upstream postPatch rewrites the go directive to our Go (1.26.7), which then
    # equals go.mod's toolchain line, so Go rejects go.mod as untidy. Remove once
    # gastownhall/beads#6752 merges and the beads input is bumped past it.
    beads-unwrapped = prev.beads-unwrapped.overrideAttrs (old: {
      postPatch = old.postPatch + ''
        go mod edit -toolchain=none
      '';
    });
  })
  (_: prev: {
    ascii-box-cli = prev.stdenvNoCC.mkDerivation rec {
      pname = "ascii-box-cli";
      version = "0.1.259";
      src = prev.fetchurl {
        url = "https://github.com/ariana-dot-dev/agent-server/releases/download/box-cli-v${version}-ascii-prod1/box-${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }-${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "x64"}";
        sha256 =
          {
            "aarch64-darwin" = "1clicbx7rk24l30gv16pn6g3ipfzix167q1kfk1n6km0j09lnw5w";
            "aarch64-linux" = "12yyrf39la1k2s0d4k5smdf0yh8fprzfg7gcg0mkn4qk457vaw6l";
            "x86_64-linux" = "0p352vy1qmmd4nmdhxvhsdggk5l1lac8lb6ry4xi35g3alnjgx61";
          }
          .${prev.stdenv.hostPlatform.system};
      };
      dontUnpack = true;
      installPhase = ''
        install -Dm755 "$src" "$out/bin/box"
      '';
      meta.mainProgram = "box";
    };

    blacksmith-testbox-cli = prev.stdenvNoCC.mkDerivation rec {
      pname = "blacksmith-testbox-cli";
      version = "0.4.61";
      src = prev.fetchurl {
        url = "https://clireleases.blacksmith.sh/cli/v${version}/${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }/${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "amd64"}/blacksmith";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "011ca8f0c5dab2f0f128801f20d8c82a58f002a19c8f2b0393cc4b4dcc42ee0c"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "4c162fa3dc27f5bfaea7f3ab680d7a7268d8a5ea091bb074c5a238165cd82c4c"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "331f4655b8c659b08ada51c9421ce3a0f151367d7cdabad7b869c451ad77963f"
          else
            "f66b761e6ca6833e16d6ed4b8f01aa74b3e2db0c1c64e5f488a9271eb4dbee22";
      };
      dontUnpack = true;
      installPhase = ''
        install -Dm755 $src $out/bin/blacksmith
      '';
      meta.mainProgram = "blacksmith";
    };

    crabbox = prev.stdenvNoCC.mkDerivation rec {
      pname = "crabbox";
      version = "0.66.0";
      src = prev.fetchurl {
        url = "https://github.com/openclaw/crabbox/releases/download/v${version}/crabbox_${version}_${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }_${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "amd64"}.tar.gz";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "027907f7f2274d0eb15fbeea6583f6f421f2645189e22671ba327f3f961efc9d"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "329cfb048374a94c6125e91fc32e0915077c1879b0713cbec7cacbac92d162b7"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "65839102bf4e7a8496528ee20641e4a0ab5cadf139ebacf90809af8926bb15da"
          else
            "cc06ee59c240df51ecde6726ed5d87bcc5b78201c9cdbd3434556048ddd65be4";
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

    devin = prev.stdenvNoCC.mkDerivation rec {
      pname = "devin";
      version = "3000.11.3";
      src = prev.fetchurl {
        url = "https://static.devin.ai/cli/${version}/devin-${version}-${
          if prev.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64"
        }-${if prev.stdenv.hostPlatform.isDarwin then "apple-darwin" else "unknown-linux"}.tar.gz";
        sha256 =
          {
            "aarch64-darwin" = "c08cc3f3507d103246b8c601a584fcc719fd77f6cc10f26cc90e9f4186640df2";
            "x86_64-darwin" = "594f89b6b0d03dffec4eabc754104e4471cc43a014a2164e2fdd7d0d752d0100";
            "aarch64-linux" = "21a2d7a8dea67987067cde7eb3fe7193a48daa8f8c3d50d414c603c4a2b67f15";
            "x86_64-linux" = "83b3b113c01bf2a3e9e100db08d77e6b086806a7754f091e20831bdfe215157e";
          }
          .${prev.stdenv.hostPlatform.system};
      };
      sourceRoot = ".";
      dontConfigure = true;
      dontBuild = true;
      installPhase = ''
        install -Dm755 bin/devin $out/bin/devin
        mkdir -p $out/share
        cp -r share/devin $out/share/devin
      '';
      meta.mainProgram = "devin";
    };

    moshi-hook = prev.stdenv.mkDerivation rec {
      pname = "moshi-hook";
      version = "0.4.3";
      src = prev.fetchurl {
        url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_${
          if prev.stdenv.hostPlatform.isDarwin then "Darwin" else "Linux"
        }_${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "x86_64"}.tar.gz";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "2f6818b7c5dc681ddeccd3f246799aa4dfb80da23103486efa08c3996aab3cdd"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "d0111b7bc5b8e4278b3da168624f0ce7ac2b46ebfff2d0cc3ebb446776de687d"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "f87000bfc866f4a877b5cd27ddf4ae3bc8fe9a54bc5022777d0295ebf6ea969a"
          else
            "3206e4f71c7ed174ed5935445e4c30fd9a7f5aff4657789cf2600c3a166428ba";
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
