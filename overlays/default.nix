{ inputs }:
let
  # Override clawdbot source to v2026.1.22
  clawdbotSourceOverride = {
    owner = "clawdbot";
    repo = "clawdbot";
    rev = "c48751a99c1aacea1092927ff85a09ee40ac374d";
    hash = "sha256-DJZulGqo2E7XvitR3kYKme9vqSfQyYs9I9fsBIpqQdQ=";
    pnpmDepsHash = "sha256-tGzKcCiZNlWlKMNNFmxcFpIvO92G9myhM+OYaGea4hw=";
  };
  # Override clawdbot-app to v2026.1.22 (fixes broken app package)
  clawdbotAppOverride = {
    version = "2026.1.22";
    url = "https://github.com/clawdbot/clawdbot/releases/download/v2026.1.22/Clawdbot-2026.1.22.zip";
    hash = "sha256-IXb+WNrSqH80mYOR62rRK+mJUhReJ+CZVPNFefgkcao=";
  };
in
[
  inputs.nur.overlays.default
  inputs.neovim-nightly-overlay.overlays.default
  # Custom clawdbot overlay with version override (replaces inputs.nix-clawdbot.overlays.default)
  (
    final: prev:
    let
      clawdbotVersion = "2026.1.22";
      basePkgs = import "${inputs.nix-clawdbot}/nix/packages" {
        pkgs = prev;
        sourceInfo = clawdbotSourceOverride;
      };
      # Override version in clawdbot-gateway (it's hardcoded in the derivation)
      # src is already correct from sourceInfo, just need to update version string
      clawdbot-gateway = basePkgs.clawdbot-gateway.overrideAttrs (old: {
        version = clawdbotVersion;
        __intentionallyOverridingVersion = true;
      });
      # Build clawdbot-app with fixed version (upstream has broken app package)
      clawdbot-app =
        if prev.stdenv.isDarwin then
          prev.stdenvNoCC.mkDerivation {
            pname = "clawdbot-app";
            version = clawdbotAppOverride.version;
            src = prev.fetchzip {
              url = clawdbotAppOverride.url;
              hash = clawdbotAppOverride.hash;
              stripRoot = false;
            };
            dontUnpack = true;
            installPhase = ''
              mkdir -p "$out/Applications"
              app_path="$(find "$src" -maxdepth 2 -name '*.app' -print -quit)"
              if [ -z "$app_path" ]; then
                echo "Clawdbot.app not found in $src" >&2
                exit 1
              fi
              cp -pR "$app_path" "$out/Applications/Clawdbot.app"
            '';
            meta = with prev.lib; {
              description = "Clawdbot macOS app bundle";
              homepage = "https://github.com/clawdbot/clawdbot";
              license = licenses.mit;
              platforms = platforms.darwin;
            };
          }
        else
          null;
      # Rebuild batteries bundle with the overridden gateway and app
      clawdbot = prev.callPackage "${inputs.nix-clawdbot}/nix/packages/clawdbot-batteries.nix" {
        clawdbot-gateway = clawdbot-gateway;
        inherit clawdbot-app;
        extendedTools = (import "${inputs.nix-clawdbot}/nix/tools/extended.nix" { pkgs = prev; }).tools;
      };
      toolNames = (import "${inputs.nix-clawdbot}/nix/tools/extended.nix" { pkgs = prev; }).toolNames;
      withTools =
        {
          toolNamesOverride ? null,
          excludeToolNames ? [ ],
        }:
        let
          toolSets = import "${inputs.nix-clawdbot}/nix/tools/extended.nix" {
            pkgs = prev;
            inherit toolNamesOverride excludeToolNames;
          };
          innerPkgs = import "${inputs.nix-clawdbot}/nix/packages" {
            pkgs = prev;
            sourceInfo = clawdbotSourceOverride;
            inherit toolNamesOverride excludeToolNames;
          };
          innerGateway = innerPkgs.clawdbot-gateway.overrideAttrs (old: {
            version = clawdbotVersion;
            __intentionallyOverridingVersion = true;
          });
        in
        innerPkgs
        // {
          clawdbot-gateway = innerGateway;
          clawdbot = prev.callPackage "${inputs.nix-clawdbot}/nix/packages/clawdbot-batteries.nix" {
            clawdbot-gateway = innerGateway;
            inherit clawdbot-app;
            extendedTools = toolSets.tools;
          };
        };
    in
    {
      inherit clawdbot clawdbot-gateway;
      clawdbotPackages = {
        inherit
          clawdbot
          clawdbot-gateway
          toolNames
          withTools
          ;
      };
    }
    // (if prev.stdenv.isDarwin then { inherit clawdbot-app; } else { })
  )
  (final: prev: {
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
  (final: prev: {
    # Provide non-deprecated alias so upstream modules using pkgs.system don't emit warnings.
    system = prev.stdenv.hostPlatform.system;
  })
  (final: prev: {
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
]
