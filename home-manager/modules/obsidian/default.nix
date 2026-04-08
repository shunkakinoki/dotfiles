{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs) host;

  # Obsidian 1.12+ ships its official CLI as the `obsidian` binary
  # (https://help.obsidian.md/cli). The CLI subcommands still load the
  # full Electron asar, so they need a display server. We wrap the real
  # binary in `xvfb-run` so each invocation gets an ephemeral virtual X
  # server, letting the CLI run on a headless host.
  #
  # `pkgs.obsidian` and `pkgs.xvfb-run` are referenced by store path here,
  # so they get pulled into the closure automatically without needing to
  # appear directly on PATH. Only this shim is exposed as `obsidian`,
  # which is exactly what memory-wiki probes for.
  obsidianHeadless = pkgs.writeShellScriptBin "obsidian" ''
    exec ${pkgs.xvfb-run}/bin/xvfb-run -a ${pkgs.obsidian}/bin/obsidian "$@"
  '';
in
# Only enable on kyber (gateway host) — desktops already get pkgs.obsidian
# directly via home-manager/packages/default.nix.
lib.mkIf host.isKyber {
  home.packages = [ obsidianHeadless ];
}
