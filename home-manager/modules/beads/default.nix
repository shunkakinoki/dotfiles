{ pkgs, ... }:
{
  # ~/.local/bin precedes every nix profile dir in PATH (see programs/fish),
  # so the flake-managed bd only wins if it also owns the ~/.local/bin entry
  # that update-local-binaries.sh used to create.
  home.file.".local/bin/bd".source = "${pkgs.beads}/bin/bd";
  home.file.".local/bin/beads".source = "${pkgs.beads}/bin/beads";
}
