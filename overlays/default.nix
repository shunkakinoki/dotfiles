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
    # Use the first tagged release that includes --attach on issue and PR commands.
    gh = prev.gh.overrideAttrs (_: {
      pname = "gh";
      version = "2.100.0";
      src = prev.fetchFromGitHub {
        owner = "cli";
        repo = "cli";
        rev = "45437bc7eeeb3359bbfddd1742f79de7652fd3e2";
        hash = "sha256-9tnSQPSqllE+Ke6LKyNbnOF1drzdEwesEuPdmWD1X5c=";
      };
      vendorHash = "sha256-ZqUs2BnasF3QBX0I2Sxh2A/CnO61Vy6gRn1hkf0n9AY=";
      buildPhase = ''
        runHook preBuild
        make GO_LDFLAGS="-s -w -X github.com/cli/cli/v2/internal/build.Date=nixpkgs" GH_VERSION=2.100.0 bin/gh manpages
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
    # Keep the Dolt archive-integrity fix independent from the shared nixpkgs
    # pin so storage recovery does not upgrade unrelated host packages.
    dolt = inputs.nixpkgs-dolt.legacyPackages.${prev.system}.dolt;
  })
  (_: prev: {
    ascii-box-cli = prev.stdenvNoCC.mkDerivation rec {
      pname = "ascii-box-cli";
      version = "0.1.228";
      src = prev.fetchurl {
        url = "https://github.com/ariana-dot-dev/agent-server/releases/download/box-cli-v${version}-ascii-prod1/box-${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }-${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "x64"}";
        sha256 =
          {
            "aarch64-darwin" = "0zhfrncihahnbln400j0n2bqxnra86q64vf4zf1vblyhwl1zwic2";
            "aarch64-linux" = "0w89dxyq16rdkxkvl88apxxpivq473ap7r5igrhi0km3k238r5bb";
            "x86_64-linux" = "1c05jp8jnf3qb7viqgd2fzjgdpmjvrw59wgnrx88q1w7k429iwjb";
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
      version = "0.4.58";
      src = prev.fetchurl {
        url = "https://clireleases.blacksmith.sh/cli/v${version}/${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }/${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "amd64"}/blacksmith";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "0b54a4398e9b35344d8fb32891703d8a393343f5001914d7482f93d068c76822"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "2bf3e7246414e2fd113d3214577bb8951015aeda57579d1f36ec75dc5c05c716"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "2384984fa9cdb943e9352b4ff6a4adf9e9ac61c194c255887413357fada27d88"
          else
            "6dabf51a4e168d7ea1d9379f09fb8e08dc57a5f8c000932b1f9d507c44bc5450";
      };
      dontUnpack = true;
      installPhase = ''
        install -Dm755 $src $out/bin/blacksmith
      '';
      meta.mainProgram = "blacksmith";
    };

    crabbox = prev.stdenvNoCC.mkDerivation rec {
      pname = "crabbox";
      version = "0.58.0";
      src = prev.fetchurl {
        url = "https://github.com/openclaw/crabbox/releases/download/v${version}/crabbox_${version}_${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }_${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "amd64"}.tar.gz";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "a1201e203d1c83ee0daee1ee2c451ad70ce032ecfdf196da2a8b2e118f07af78"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "045bb84c1dca4ae9a02ddbf4b942c62213583ea8c1f15194ec4ab319d367aa34"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "a84d395ff935940449dd295b4453d993bfc4692350b3d2a8f45e09243eb1fa4e"
          else
            "59d78b578c3c1ed1c78f9aac6b98cbec2c8567feca4d56cfde2ba531e407c369";
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
      version = "3000.10.21";
      src = prev.fetchurl {
        url = "https://static.devin.ai/cli/${version}/devin-${version}-${
          if prev.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64"
        }-${if prev.stdenv.hostPlatform.isDarwin then "apple-darwin" else "unknown-linux"}.tar.gz";
        sha256 =
          {
            "aarch64-darwin" = "c0b97f8197bf3ce895ff14aa19257c511154b49a0a195bba4962acb5e475c68e";
            "x86_64-darwin" = "4725d6b0dbbf6f71d833b5489469dc8b5c4a4f929926f94d500952a4cb7bbad8";
            "aarch64-linux" = "a63124ed2f8406a5d44a162fa2eb05b9c0f218a6b131e2ca1335d4a335c70a6c";
            "x86_64-linux" = "7cac6f5739ba3a3e5542f3b7fa07ed902d6dfb96ca22e4c63ae84c03bb7db47c";
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
      version = "0.3.22";
      src = prev.fetchurl {
        url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_${
          if prev.stdenv.hostPlatform.isDarwin then "Darwin" else "Linux"
        }_${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "x86_64"}.tar.gz";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "4031728e9f71bb59d49bba7a2db2d260049ee14ddcf6d63e70e5c82f88d8fdda"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "ee92dfb18f293a0bf2b944e446541c7bc59ad209ebced393150e639ad879a875"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "5d8d671a63a5178bb35f64bd2e0d0b7d3fee66b8096188d062ab8eeca4e4bd0f"
          else
            "0334fded7d237f4dbe2b804927286ee1ca56bdc5581cd520056d0e193cc876a1";
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
