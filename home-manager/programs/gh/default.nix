{ config, pkgs, ... }:
{
  programs.gh = {
    enable = true;
    extensions = with pkgs; [
      gh-markdown-preview
      gh-signoff
      gh-stack
    ];
    settings = {
      editor = "nvim";
      git_protocol = "https";
      prompt = "enabled";
    };
  };

  # Hand-run `gh auth setup-git` pins a GC-able store path in ~/.gitconfig and
  # resets the Home Manager helper; drop those sections on every switch.
  home.activation.removeStaleGhCredentialHelpers = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../activation/remove-stale-gh-credential-helpers.sh}" \
      "${pkgs.git}/bin/git" \
      "${config.home.homeDirectory}/.gitconfig"
  '';
}
