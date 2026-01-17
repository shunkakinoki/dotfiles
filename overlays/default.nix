{ inputs }:
let
  # Override clawdbot source to v2026.1.16-2
  clawdbotSourceOverride = {
    owner = "clawdbot";
    repo = "clawdbot";
    rev = "be37b39782e0799ba5b9533561de6d128d50c863";
    hash = "sha256-y1ToqEcfl0yVAJkVld0k5AX5tztiE7yJt/F7Rhg+dAc=";
    pnpmDepsHash = "sha256-NPQrkhhvAoIYzR1gopqsErps1K/HkfxmrPXpyMlN0Bc=";
  };
in
[
  inputs.nur.overlays.default
  inputs.neovim-nightly-overlay.overlays.default
  # Custom clawdbot overlay with version override (replaces inputs.nix-clawdbot.overlays.default)
  (final: prev:
    let
      clawdbotVersion = "2026.1.16-2";
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
      # Rebuild batteries bundle with the overridden gateway
      clawdbot = prev.callPackage "${inputs.nix-clawdbot}/nix/packages/clawdbot-batteries.nix" {
        clawdbot-gateway = clawdbot-gateway;
        clawdbot-app = if prev.stdenv.isDarwin then basePkgs.clawdbot-app or null else null;
        extendedTools = (import "${inputs.nix-clawdbot}/nix/tools/extended.nix" { pkgs = prev; }).tools;
      };
      toolNames = (import "${inputs.nix-clawdbot}/nix/tools/extended.nix" { pkgs = prev; }).toolNames;
      withTools = { toolNamesOverride ? null, excludeToolNames ? [] }:
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
        innerPkgs // {
          clawdbot-gateway = innerGateway;
          clawdbot = prev.callPackage "${inputs.nix-clawdbot}/nix/packages/clawdbot-batteries.nix" {
            clawdbot-gateway = innerGateway;
            clawdbot-app = if prev.stdenv.isDarwin then innerPkgs.clawdbot-app or null else null;
            extendedTools = toolSets.tools;
          };
        };
    in
    {
      inherit clawdbot clawdbot-gateway;
      clawdbotPackages = {
        inherit clawdbot clawdbot-gateway toolNames withTools;
      };
    } // (if prev.stdenv.isDarwin then { clawdbot-app = basePkgs.clawdbot-app or null; } else {})
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
