{
  # Disable nix-darwin's Nix management to allow Determinate Nix to manage the daemon.
  # Determinate uses its own daemon that conflicts with nix-darwin's native Nix management.
  # Note: This disables nix.* options like nix.settings and nix.optimise.
  nix.enable = false;
}
