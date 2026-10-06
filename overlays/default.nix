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
        # Nix's glibc loader never searches the host's /usr/lib, so a native
        # Node addon bun dlopens (prebuilt image libraries, for example) cannot
        # find libstdc++ on a non-NixOS host unless the caller exports it, as
        # a non-interactive SSH command does not. Append only the gcc runtime:
        # the full Nix library set would shadow the host glibc for system
        # binaries bun spawns, such as browsers.
        nativeBuildInputs =
          (old.nativeBuildInputs or [ ])
          ++ prev.lib.optionals prev.stdenv.hostPlatform.isLinux [ prev.makeBinaryWrapper ];
        postFixup =
          (old.postFixup or "")
          + prev.lib.optionalString prev.stdenv.hostPlatform.isLinux ''
            wrapProgram $out/bin/bun \
              --suffix LD_LIBRARY_PATH : ${prev.lib.makeLibraryPath [ prev.stdenv.cc.cc.lib ]}
          '';
      }
    );
  })
  (_: prev: {
    # Use the first tagged release that includes --attach on issue and PR commands.
    # gh's go.mod requires Go 1.27, newer than the pinned nixpkgs default.
    gh = (prev.gh.override { buildGoModule = prev.buildGo127Module; }).overrideAttrs (_: {
      pname = "gh";
      version = "2.102.0";
      src = prev.fetchFromGitHub {
        owner = "cli";
        repo = "cli";
        rev = "fc4b137cdef0a6bd28fd461b7cf9c84a5812a8cd";
        hash = "sha256-txjOmo46nwRxIutYR/lnFgYEWZpkbWC/ilrMAfTaFZc=";
      };
      vendorHash = "sha256-hsG6wc7AfgPZhkWwO8Xzu4yR54Rp5+Z6yeTjwnI9S+o=";
      buildPhase = ''
        runHook preBuild
        make GO_LDFLAGS="-s -w -X github.com/cli/cli/v2/internal/build.Date=nixpkgs" GH_VERSION=2.102.0 bin/gh manpages
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
    boat-cli = prev.stdenvNoCC.mkDerivation rec {
      pname = "boat-cli";
      version = "1.0.38";
      src = prev.fetchurl {
        url = "https://github.com/ariana-dot-dev/agent-server/releases/download/boat-cli-v${version}/boat-${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }-${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "x64"}";
        sha256 =
          {
            "aarch64-darwin" = "1jdhv6qsczba1nwcw06v01xnvzx5r115ys5f402wnvandd5idvb4";
            "aarch64-linux" = "03zlzc4w18lf841ss35gk1dqahlmlssrlgvfnmra9a28klfmgm94";
            "x86_64-linux" = "130zkblp950f20nj2s31sw5ic8jb6gz99l4wyxc7v2b0yhzaap3m";
          }
          .${prev.stdenv.hostPlatform.system};
      };
      dontUnpack = true;
      installPhase = ''
        install -Dm755 "$src" "$out/bin/boat"
      '';
      meta.mainProgram = "boat";
    };

    blacksmith-testbox-cli = prev.stdenvNoCC.mkDerivation rec {
      pname = "blacksmith-testbox-cli";
      version = "0.4.65";
      src = prev.fetchurl {
        url = "https://clireleases.blacksmith.sh/cli/v${version}/${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }/${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "amd64"}/blacksmith";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "5908140e555208622bd3caa35eabd5593dd520bbe6ecab9bce8fa2f5958e12b0"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "c6b251ce64903ed7c8a90adde3858327dc5909accf105ad6d56965a382021bfc"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "731cdb91377b84d3e28bc78f07a7348b5516e762e83fe973d033a307f7fbe78a"
          else
            "f4e006f1f2ff544c4026e5eb5a51ef261e306c67f2905b3005ec90773700a752";
      };
      dontUnpack = true;
      installPhase = ''
        install -Dm755 $src $out/bin/blacksmith
      '';
      meta.mainProgram = "blacksmith";
    };

    crabbox = prev.stdenvNoCC.mkDerivation rec {
      pname = "crabbox";
      version = "0.71.0";
      src = prev.fetchurl {
        url = "https://github.com/openclaw/crabbox/releases/download/v${version}/crabbox_${version}_${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }_${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "amd64"}.tar.gz";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "118c9239a565f1fa1581973ca51f45d173252d219105061c0772d8cd8ff41646"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "63a4089e7d04a9165a9718ff98e24a91d2ad2c77416c540f6dbf77b93143526f"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "96a1c4a469177b407cd831a9bf9b5fc51aa637e0170da0119aa137612190f387"
          else
            "3b577c16b8c17e7e1b5e0de967fe6380eb12de7a3fc893ac1131bb70050eb3f9";
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
      version = "0.4.17";
      src = prev.fetchurl {
        url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_${
          if prev.stdenv.hostPlatform.isDarwin then "Darwin" else "Linux"
        }_${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "x86_64"}.tar.gz";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "10c657ad2e84eda85632dfa3c8c85b00a5145e312c607c03b8082dee3ecee614"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "32677a195d08f309519b91585edee43d1824370c83fa2b57a7592ba78b33fd81"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "99658e391866461afb11f359dd77ca428ad9a688864aa4c6a034b43055b6ec7b"
          else
            "f8cbbf611f59d142144b547ba092fce33f8ac91bc448b86f84b206db20b314a7";
      };
      sourceRoot = ".";
      dontConfigure = true;
      dontBuild = true;
      installPhase = ''
        install -Dm755 moshi-hook $out/bin/moshi-hook
        ln -s moshi-hook $out/bin/moshi
      '';
    };

    # Namespace's devbox CLI, not the unrelated Jetify devbox in nixpkgs.
    namespace-devbox = prev.stdenvNoCC.mkDerivation rec {
      pname = "namespace-devbox";
      version = "0.0.196";
      src = prev.fetchurl {
        url = "https://get.namespace.so/packages/devbox/v${version}/devbox_${version}_${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }_${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "amd64"}.tar.gz";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "a33e0a7a716d2fb0bfd4c39ce9fd785f0e4efd5e92e05483599c0c2b23840897"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "89d72d239059ded638bcb64da8c2ee164097b7faac1840e31f2186f0aa155555"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "865ff1f64fb33d6773e00f23cc941f15e67d8a6797438c00ff9b8e0aa9632db2"
          else
            "cfa0c997bec598fdd1b9d28bfdac755457f670b6d11fc1b87dee2fb069a82c4b";
      };
      sourceRoot = ".";
      dontConfigure = true;
      dontBuild = true;
      installPhase = ''
        install -Dm755 devbox $out/bin/devbox
      '';
      meta.mainProgram = "devbox";
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
