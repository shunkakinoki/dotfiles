{ config, pkgs, ... }:
let
  baseConfig = builtins.fromJSON (builtins.readFile ./config.json);
  hydratedConfig = baseConfig // {
    git_path = "${pkgs.git}/bin/git";
  };
in
{
  home.file.".git-ai/config.json" = {
    text = builtins.toJSON hydratedConfig;
    force = true;
  };

  # Install git-ai wrapper binaries (~/.git-ai/bin/git, git-ai, git-og)
  home.activation.installGitAiWrapper = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -x "$HOME/.git-ai/bin/git" ]; then
      echo "Installing git-ai wrapper..."
      $DRY_RUN_CMD ${pkgs.curl}/bin/curl -fsSL https://usegitai.com/install.sh | $DRY_RUN_CMD ${pkgs.bash}/bin/bash 2>/dev/null || true
    fi
  '';
}
