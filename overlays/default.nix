{ inputs }:
[
  # The cachix test suite is currently failing to build from source with a symbol lookup error. This overlay disables the tests to work around the issue.
  (final: prev: {
    cachix = prev.cachix.overrideAttrs (oldAttrs: {
      doCheck = false;
    });
  })
  inputs.nur.overlays.default
  inputs.neovim-nightly-overlay.overlays.default
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
]
