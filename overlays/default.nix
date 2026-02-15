{ inputs }:
[
  inputs.nur.overlays.default
  inputs.neovim-nightly-overlay.overlays.default
  inputs.foundry.overlay
  (final: prev: {
    # Pin argocd to stable version due to broken argocd-ui in unstable (yarn hash mismatch)
    argocd = inputs.nixpkgs-stable.legacyPackages.${prev.stdenv.hostPlatform.system}.argocd;
  })
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
  (final: prev: {
    nightlyPkgs = import inputs.nixpkgs-nightly {
      system = prev.system;
      config = prev.config;
      overlays = [ ];
    };
    codex = final.nightlyPkgs.codex;
    claude-code = final.nightlyPkgs.claude-code;
    opencode = final.nightlyPkgs.opencode;
  })
]
