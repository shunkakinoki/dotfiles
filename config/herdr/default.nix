_: {
  home.file.".config/herdr/config.toml" = {
    source = ./config.toml;
    force = true;
  };
  home.file.".config/herdr/agent-detection/opencode.toml".source = ./agent-detection/opencode.toml;
}
