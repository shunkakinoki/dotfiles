{ config, ... }:
{
  # Gitleaks reads $GITLEAKS_CONFIG when run outside a repo with a local .gitleaks.toml.
  home.file.".config/gitleaks/config.toml".source = ./config.toml;
  home.sessionVariables = {
    GITLEAKS_CONFIG = "${config.home.homeDirectory}/.config/gitleaks/config.toml";
  };
}
