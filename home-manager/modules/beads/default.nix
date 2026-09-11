{ pkgs, ... }:
{
  # ~/.local/bin precedes every nix profile dir in PATH (see programs/fish),
  # so the flake-managed bd only wins if it also owns the ~/.local/bin entry
  # that update-local-binaries.sh used to create.
  #
  # force is required to take that entry over: backupFileExtension only moves
  # regular files aside, so the leftover ulb symlink would abort activation
  # (check-link-targets.sh skips both backup branches when the target is a
  # symlink) on every host that still has one.
  home.file.".local/bin/bd" = {
    source = "${pkgs.beads}/bin/bd";
    force = true;
  };
  home.file.".local/bin/beads" = {
    source = "${pkgs.beads}/bin/beads";
    force = true;
  };
}
