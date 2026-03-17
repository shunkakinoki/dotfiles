{ inputs }:
[
  inputs.nur.overlays.default
  inputs.neovim-nightly-overlay.overlays.default
  (final: prev: {
    # Use stable nixpkgs foundry instead of shazow/foundry.nix nightly overlay
    # to avoid unreliable nightly binary downloads.
    foundry-bin = prev.foundry;
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
    # Hide empty action bar in hyprpanel notifications when no valid actions exist.
    # Notifications with empty action IDs (e.g. from Claude Code) bypass the length
    # guard and render a blank bar. Filter them out before the guard and the map.
    hyprpanel = prev.hyprpanel.overrideAttrs (oldAttrs: {
      postPatch = (oldAttrs.postPatch or "") + ''
        substituteInPlace src/components/notifications/Notification/index.tsx \
          --replace-fail \
          'notification.get_actions().length' \
          'notification.get_actions().filter((a) => a.id !== "").length'
        substituteInPlace src/components/notifications/Actions/index.tsx \
          --replace-fail \
          'notification.get_actions().map' \
          'notification.get_actions().filter((a) => a.id !== "").map'
      '';
    });
  })
  (final: prev: {
    nightlyPkgs = import inputs.nixpkgs-nightly {
      system = prev.system;
      config = prev.config;
      overlays = [ ];
    };
    # deno 2.6.10 on nixpkgs-unstable has broken check phase (integration_tests vs integration_test)
    # Use nightly (master) which has the fix and is in the binary cache
    deno = final.nightlyPkgs.deno;
    codex = final.nightlyPkgs.codex;
    claude-code = final.nightlyPkgs.claude-code;
    opencode = final.nightlyPkgs.opencode;
  })
]
