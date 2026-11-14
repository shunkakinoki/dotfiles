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
      version = "2.104.0";
      src = prev.fetchFromGitHub {
        owner = "cli";
        repo = "cli";
        rev = "3d5a9e355a837f2f5ee78d7484c118cc1342ad1a";
        hash = "sha256-HrIk40AP5VT7lvBLZXzwTQFyJWexKfeYlLokar+2KOI=";
      };
      vendorHash = "sha256-ggv4DIkA25qacx65RZ2mPWpbTcbl4KaZoj+JEkfwPXI=";
      buildPhase = ''
        runHook preBuild
        make GO_LDFLAGS="-s -w -X github.com/cli/cli/v2/internal/build.Date=nixpkgs" GH_VERSION=2.104.0 bin/gh manpages
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
          # t3code 0.1.9 pins one pnpm deps hash, but fetchPnpmDeps resolves
          # platform-specific optional packages, so it only reproduces on the
          # system upstream generated it from. Every x86_64-linux build fails on
          # the fixed-output mismatch; other systems keep the upstream hash.
          # https://github.com/numtide/llm-agents.nix
          let
            pnpmDepsHashes = {
              x86_64-linux = "sha256-lZv88yvoDuGlcApHktsbR1OiTtffzQ92wu9qYbFxR8s=";
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
      version = "1.0.100";
      src = prev.fetchurl {
        url = "https://github.com/ariana-dot-dev/agent-server/releases/download/boat-cli-v${version}/boat-${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }-${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "x64"}";
        sha256 =
          {
            "aarch64-darwin" = "1cfv4nrf85pjvqjdfcs0cnwwgmnxrsxyvfsb42yyd4dsn384ld77";
            "aarch64-linux" = "0vyfdqry6jf6ywai08via2c7vdn3fzqp0di5hcfggyqa7830rgid";
            "x86_64-linux" = "0zfm14n2gk135z02a6fkrsk23vzgd0da94cba9h9k96s2g7flv7w";
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
      version = "3000.12.57";
      src = prev.fetchurl {
        url = "https://static.devin.ai/cli/${version}/devin-${version}-${
          if prev.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64"
        }-${if prev.stdenv.hostPlatform.isDarwin then "apple-darwin" else "unknown-linux"}.tar.gz";
        sha256 =
          {
            "aarch64-darwin" = "c0ec7f558f25a9e6b117743bd06781e1a24c78d8552727a9539601de94912f12";
            "x86_64-darwin" = "18571f6f9596bd13894b35e1a3749ce6a0b65337c1ac5ccf07e7ecfbaa7828aa";
            "aarch64-linux" = "e0f03ce263e30940122547f73e1c57d4f163391553fd37c6c856b366463d766f";
            "x86_64-linux" = "0946784ef886d716e82a8026f76933bf0a6e4f0a804a23722bb62047e8c07d4a";
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
      version = "0.4.55";
      src = prev.fetchurl {
        url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_${
          if prev.stdenv.hostPlatform.isDarwin then "Darwin" else "Linux"
        }_${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "x86_64"}.tar.gz";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "8bafd3bdfe02aac1028e8e7bd53afb42324f988b9af60b40cfd275c63609c299"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "fab25d77e2936588a9c1e8f46b2cb908b8d527919ffea89083e603db12d938fd"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "8238aca6009b5660de0429370d9c2b68e357cf58fe9cbc734f41c461a83ee80a"
          else
            "8eb9b3e5ac7b7b294e368c87ec8d99ab04305209294a146e891948ff0e7ff6e1";
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
      version = "0.0.213";
      src = prev.fetchurl {
        url = "https://get.namespace.so/packages/devbox/v${version}/devbox_${version}_${
          if prev.stdenv.hostPlatform.isDarwin then "darwin" else "linux"
        }_${if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "amd64"}.tar.gz";
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "7fba7260f2152f2e6830aff699ad3cb9eccb182cc6ace92fe4f2acea81456aaf"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "6590ba8215bbd13d29f0e4efd6766f1428f6549fbce2761a7839b4d3703577f6"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "0c3b8f78b3c862e8f69502dc358fc9ffbeb2bf21ca7d7e5a0ce233bc5265ebd9"
          else
            "c4081f2711f5eb9f5268dff2037082d27fbcdbd029ba9a38ff5d7965f85fd3b2";
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
