{ pkgs }:
let
  inherit (pkgs) lib;
in
# On macOS, Tailscale is installed via Homebrew cask which manages the app and daemon.
# On Linux (non-NixOS), we install the CLI tools; the tailscaled daemon requires system-level setup.
# For NixOS, enable services.tailscale in the system configuration.
lib.mkIf pkgs.stdenv.isLinux {
  home.packages = [ pkgs.tailscale ];
}
