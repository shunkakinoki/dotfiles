{ inputs }:
let
  awsLcPrefix =
    pkgs:
    pkgs.symlinkJoin {
      name = "aws-lc-rust";
      paths = [
        pkgs.aws-lc.out
        pkgs.aws-lc.dev
      ];
      # aws-lc-sys 0.45 requires this layout for an explicit system prefix.
      postBuild = ''
        if [ ! -e "$out/include/openssl" ]; then
          ln -s aws-lc/openssl "$out/include/openssl"
        fi
      '';
    };
in
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
    codex = prev.codex.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.pkg-config ];
      buildInputs = (old.buildInputs or [ ]) ++ [ prev.openssl ];
      env = (old.env or { }) // {
        # AWS-LC needs its own headers, libraries and bindings in one prefix.
        AWS_LC_SYS_SYSTEM_DIR = "${awsLcPrefix prev}";
        OPENSSL_DIR = "${prev.openssl.dev}";
        OPENSSL_LIB_DIR = "${prev.openssl.out}/lib";
        OPENSSL_INCLUDE_DIR = "${prev.openssl.dev}/include";
      };
    });
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
  (
    _: prev:
    let
      # These crates' -sys dependencies probe system libraries through
      # pkg-config, which the nixpkgs derivations do not provide, so the build
      # script panics.
      withPkgConfigLibs =
        libs: pkg:
        pkg.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.pkg-config ];
          buildInputs = (old.buildInputs or [ ]) ++ libs;
        });
    in
    {
      fnm = withPkgConfigLibs [ prev.zstd ] prev.fnm;
      below = withPkgConfigLibs [ prev.zstd ] prev.below;
      aichat = withPkgConfigLibs [ prev.oniguruma ] prev.aichat;
    }
  )
  (_: prev: {
    # gh-stack 0.3.0's cmd tests spawn git per rebase case and exceed Go's 600s
    # test timeout on loaded hosts, failing every NixOS build that includes it.
    gh-stack = prev.gh-stack.overrideAttrs (_: {
      doCheck = false;
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
    # lane dispatch fleet-wide. Pin the release the repo
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
      version = "2.106.0";
      src = prev.fetchFromGitHub {
        owner = "cli";
        repo = "cli";
        rev = "529111a21612ff1e29dc45e567a157df24e0e243";
        hash = "sha256-LssgKMOk1mnqHNkKijO5kkKxYqU6aGD1afNPPi0dQN0=";
      };
      vendorHash = "sha256-n2SJaKih74D/hos0aHrNokWopuF04uoGYlHCxQ/2IGw=";
      buildPhase = ''
        runHook preBuild
        make GO_LDFLAGS="-s -w -X github.com/cli/cli/v2/internal/build.Date=nixpkgs" GH_VERSION=2.106.0 bin/gh manpages
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
          # t3code 0.1.11 pins one pnpm deps hash, but fetchPnpmDeps resolves
          # platform-specific optional packages, so it only reproduces on the
          # system upstream generated it from. Every x86_64-linux build fails on
          # the fixed-output mismatch; other systems keep the upstream hash.
          # https://github.com/numtide/llm-agents.nix
          let
            pnpmDepsHashes = {
              x86_64-linux = "sha256-bq+hxFjUgRk0NYaMkz7rtpyQtQ3ora5J2efi9fiRk9k=";
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
  (_: prev: {
    boat-cli = prev.stdenvNoCC.mkDerivation rec {
      pname = "boat-cli";
      version = "1.0.106";
      src = prev.fetchurl {
        url = "https://github.com/ariana-dot-dev/agent-server/releases/download/boat-cli-v${version}/boat-${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }-${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "x64"}";
        sha256 =
          {
            "aarch64-darwin" = "072bvxjkrvjrd8m6k6dyv4vz7z0ijnlm133y250d5r879wpr0ndq";
            "aarch64-linux" = "1nzicyxwf0wxcdq58ar5qd6c32n5pid5aywcwwwkjg58nj3pnv2x";
            "x86_64-linux" = "1512xp7m3aa11znfirid2cw6hrzizaa5xmi61kzwrnlgnc6cmgn2";
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
      version = "0.7.30";
      src = prev.fetchurl {
        url = "https://clireleases.blacksmith.sh/cli/v${version}/${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }/${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "amd64"}/blacksmith";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "52981a95537c040c7b352fb242381097cc0a33fdcf307eb928a758594c7feb0d"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "782bd47a43565602431185d1511185c388c730417be85886eebef95626f7b66c"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "f3647d5cda3a920c376ec70c1adc5a6cfd21ad10e69df74e84b9b04430b67dfb"
          else
            "e80dfaf247c1ff36540f310865e4776370d4c128f24b6299d267404c6aa24e87";
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
      version = "3000.15.14";
      src = prev.fetchurl {
        url = "https://static.devin.ai/cli/${version}/devin-${version}-${
          if prev.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64"
        }-${if prev.stdenv.hostPlatform.isDarwin then "apple-darwin" else "unknown-linux"}.tar.gz";
        sha256 =
          {
            "aarch64-darwin" = "23911fdf9b5c45ebefa382e57ff1996e762c2b30a2fe1f4b536fa633e2fcbd1f";
            "x86_64-darwin" = "5f9197bac49d90c1c213a9405326588503d7813942f347cdcc4a21bdab6b5189";
            "aarch64-linux" = "66a84d89ffff16bb0c4acdd8597102d752b3f4bf4ab53ff249637ac6ec698f87";
            "x86_64-linux" = "d219f885ed601d1424ae2ecdf5b37441cf60f15a38a4961d2a6f0b41ec913f28";
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
      version = "0.4.66";
      src = prev.fetchurl {
        url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_${
          if prev.stdenv.hostPlatform.isDarwin then "Darwin" else "Linux"
        }_${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "x86_64"}.tar.gz";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "0c0b7c832d39b6c3a6946daa1d0f9fff4f54b6b8480eecc83f7334d5d186930c"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "3d13a96d0416275b2e11c10c583ba4a9628de67de0077c3099d96cb3d65e58b2"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "11fd367e23e749367aa416415474a17a088007766b6aef398bfce92388358cd8"
          else
            "d48abc3f292f3aee4ccbd5b3f9a8aee7a027b02cc4ac2de6cda34c972be286b8";
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
      version = "0.0.214";
      src = prev.fetchurl {
        url = "https://get.namespace.so/packages/devbox/v${version}/devbox_${version}_${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }_${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "amd64"}.tar.gz";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "aa5667448f1db06870521a8bc0097d36142295c672ef87901689fdfc798d44b9"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "7991170ffd7fd5d4334f3e744334a208cc021945dd68c79f9a33cc60a698e5d1"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "348d1aba3196ec399f846be76e5293409e132ffd9f7e8aed39ea958d8c878ef7"
          else
            "cd17e03fc62ff76570ee5c5400c088ead95c30b02ce55256a6caf82aef6dfa9d";
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
    inherit (final.nightlyPkgs) deno claude-code;
    codex = final.nightlyPkgs.codex.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.pkg-config ];
      buildInputs = (old.buildInputs or [ ]) ++ [ final.openssl ];
      env = (old.env or { }) // {
        AWS_LC_SYS_SYSTEM_DIR = "${awsLcPrefix final}";
        OPENSSL_DIR = "${final.openssl.dev}";
        OPENSSL_LIB_DIR = "${final.openssl.out}/lib";
        OPENSSL_INCLUDE_DIR = "${final.openssl.dev}/include";
      };
    });
  })
]
