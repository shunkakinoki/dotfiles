{ inputs }:
[
  inputs.nur.overlays.default
  inputs.neovim-nightly-overlay.overlays.default
  inputs.foundry.overlay
  (_: prev: {
    # Beads checks the live SQL server's engine version before opening a store.
    # Keep the managed CLI and server on its upstream pin, ahead of nixpkgs.
    dolt = prev.stdenvNoCC.mkDerivation rec {
      pname = "dolt";
      version = "2.6.0";
      src = prev.fetchurl {
        url = "https://github.com/dolthub/dolt/releases/download/v${version}/dolt-${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }-${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "amd64"}.tar.gz";
        hash =
          {
            "aarch64-darwin" = "sha256-AY0UkEtaZEs/qIyixrW5QHVsrOWSxpsFqFh6lFh+F90=";
            "x86_64-darwin" = "sha256-8g7R7JbQbWJ/YBF26Az2MBQKBj7eDr8SXCjPDtTniaI=";
            "aarch64-linux" = "sha256-bKXLpq845rUqzWb6I0ceOS8FT2vRXAAESYxJG5um7N4=";
            "x86_64-linux" = "sha256-qNTC4ulLhf01ksuAdIBE+EbM/QPSWlNu0fdUuvfaZAE=";
          }
          .${prev.stdenv.hostPlatform.system};
      };
      dontConfigure = true;
      dontBuild = true;
      dontStrip = true;
      installPhase = ''
        runHook preInstall
        install -Dm755 bin/dolt $out/bin/dolt
        install -Dm644 LICENSES $out/share/doc/dolt/LICENSES
        runHook postInstall
      '';
      meta = prev.dolt.meta;
    };
  })
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
    # The orchestration repo pins `bun@1.4.4` and its bootstrap
    # (`scripts/orchestration-bootstrap.ts`) refuses to run without
    # `process.execve`, which the locked nixpkgs-unstable bun (1.3.13) lacks.
    # Every fleet lane shells out to `$HOME/.bun/bin/bun`, so a stale bun fails
    # `beads:verify` and lane dispatch fleet-wide. Pin the release the repo
    # declares; the derivation only installs the released binary.
    bun = prev.bun.overrideAttrs (
      finalAttrs: old: {
        version = "1.4.4";
        __intentionallyOverridingVersion = true;
        passthru = old.passthru // {
          sources = {
            "aarch64-darwin" = prev.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}/bun-darwin-aarch64.zip";
              hash = "sha256-wkDX8My5DCY6hJ/NsJt+5iYw2SE0jtaq/ahrnVd7xRA=";
            };
            "aarch64-linux" = prev.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}/bun-linux-aarch64.zip";
              hash = "sha256-uqa7NvUdblhWHgK76oJQOKnfRU9nPW13bou/hvjHhQ4=";
            };
            "x86_64-linux" = prev.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}/bun-linux-x64-baseline.zip";
              hash = "sha256-4ERutVmVdy65iUvrrppr42jZhai5Jx7hJEhvmUbu3XY=";
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
    gh = prev.gh.overrideAttrs (_: {
      pname = "gh";
      version = "2.103.3";
      src = prev.fetchFromGitHub {
        owner = "cli";
        repo = "cli";
        rev = "63837fb778d6a39f02be0ce76ff89f2bc8d74bdc";
        hash = "sha256-L18wWb8cPWscylx3C+uqE7/2bJt2ApE3ldQh6tXwSKk=";
      };
      vendorHash = "sha256-e9E2iTwF8kYNgW7Vs5upQBD2VT2lJ4dZcUDUk+igq/Y=";
      buildPhase = ''
        runHook preBuild
        make GO_LDFLAGS="-s -w -X github.com/cli/cli/v2/internal/build.Date=nixpkgs" GH_VERSION=2.103.3 bin/gh manpages
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
    {
      llm-agents =
        (prev.llm-agents or { })
        // {
          # Keep every managed client and server on the same released protocol.
          herdr = inputs.herdr.packages.${prev.stdenv.hostPlatform.system}.default;
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
          # t3code 0.1.7 pins one pnpm deps hash, but fetchPnpmDeps resolves
          # platform-specific optional packages, so it only reproduces on the
          # system upstream generated it from. Every x86_64-linux build fails on
          # the fixed-output mismatch; other systems keep the upstream hash.
          # https://github.com/numtide/llm-agents.nix
          let
            pnpmDepsHashes = {
              x86_64-linux = "sha256-hVpxbHZ5syedAc1Zc20TkxSgB6VA3XQGubQMx6e0njA=";
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
      version = "1.0.92";
      src = prev.fetchurl {
        url = "https://github.com/ariana-dot-dev/agent-server/releases/download/boat-cli-v${version}/boat-${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }-${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "x64"}";
        sha256 =
          {
            "aarch64-darwin" = "03pvhwg90frrwvcs3b2w6sd63l25x15vl0pc8jkiw2zwj4g40hkc";
            "aarch64-linux" = "0df7r3qg86433dn8bdlms72c97cl8r646ywhybiimpj24n2pfw89";
            "x86_64-linux" = "088phhj2l2100n8y60h0ljs7ch5qsvmq2m9n9mfl6cdzqvrghqkn";
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
      version = "0.5.3";
      src = prev.fetchurl {
        url = "https://clireleases.blacksmith.sh/cli/v${version}/${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }/${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "amd64"}/blacksmith";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "089a301ea5cc93a7560c7f1106911547fdfd46fc5c0cef7079e2a62a22e971ce"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "4acca15cb108b2ccff295dfd3e444b81a90fd523d5744c65fc52a3ecbbce7d17"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "51a13e1e2f44aa79c9bbce5bbee849ef749aea95cb1201ef3fea3108520133f8"
          else
            "8b62cd57b74202d87549e8ffbaa0ae5e51add18b6ca97c019b04783fb9bab6fc";
      };
      dontUnpack = true;
      installPhase = ''
        install -Dm755 $src $out/bin/blacksmith
      '';
      meta.mainProgram = "blacksmith";
    };

    crabbox = prev.stdenvNoCC.mkDerivation rec {
      pname = "crabbox";
      # crabbox hold: 0.72+ static-host sync fails with rsync exit 127 (staged --rsync-path receiver); unpin once fixed upstream
      version = "0.70.0";
      src = prev.fetchurl {
        url = "https://github.com/openclaw/crabbox/releases/download/v${version}/crabbox_${version}_${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }_${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "amd64"}.tar.gz";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "3fe2cbaf9b6b6573b8416b285fb2eb8755a466b7f1c42a387266fc79304c7892"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "75820218b2d7c12c88a3bfa5dd610973577953e529386f7ee84d19ad9d749b85"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "4f70e5ae4fe16f7f3562b5b4cdf137dadbdfb763ed6ff94404e67e91b9d8ada0"
          else
            "9184ce858f507662c1e97fb164d45ce7d973d50962cc84b1c3c9e1ebe7f71654";
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
      version = "3000.12.17";
      src = prev.fetchurl {
        url = "https://static.devin.ai/cli/${version}/devin-${version}-${
          if prev.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64"
        }-${if prev.stdenv.hostPlatform.isDarwin then "apple-darwin" else "unknown-linux"}.tar.gz";
        sha256 =
          {
            "aarch64-darwin" = "7331731afa01db2c4848b9435e395e4bda534db4b100c188a7efe95173e6ccac";
            "x86_64-darwin" = "c854806bc12fc4b0969e21209f858cb4a6c580bfafcff062235a1db9031c2d5f";
            "aarch64-linux" = "e98b39e71122c82a366fdaba99dc0b0531ab0fd6c95ec78031b57db7f9bd5093";
            "x86_64-linux" = "16b1414dcb50450e654954f10cd38107f93e450d76b0dea63d0b5a65ca600d45";
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
      version = "0.4.50";
      src = prev.fetchurl {
        url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_${
          if prev.stdenv.hostPlatform.isDarwin then "Darwin" else "Linux"
        }_${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "x86_64"}.tar.gz";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "793c56b2f02c3e3436e2f82523bb6e1538bfff4de3ec98b6b1e9270d6f167da3"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "6819898a1135e5454b54d33eeff283265dd3a11257142863259dcf08ad20e77d"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "f40d3c5eb0a6bf85d938ec78675f7ba0446ddbe2eb273f63187a8bdbb85917a5"
          else
            "ee7fe2f6d036fe9d6c032e889d156af8567edb5e5486a687dd0db82922c81462";
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
      version = "0.0.211";
      src = prev.fetchurl {
        url = "https://get.namespace.so/packages/devbox/v${version}/devbox_${version}_${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }_${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "amd64"}.tar.gz";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "118a05c94e8997a3d55bac27f19f4e85845ee07cd0bbb8280c5e82863e3b3711"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "e69fd25c046c8f1f5ed9c563f8fc32827564db4d76a74a35a03415c258e8b745"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "d395c22c9e4c9dc3d77cd3274a0ce4ec9d866796b9260c9a4b92274a3024d363"
          else
            "ba162994020a4aea0f51705e2915c00754a3347ddf4ff2da85d70c1986ff67fc";
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
      ;
  })
]
