{ config, pkgs, ... }:
{
  home.file."Library/Application Support/io.datasette.llm/extra-openai-models.yaml" = {
    enable = pkgs.stdenv.isDarwin;
    source = config.lib.file.mkOutOfStoreSymlink ./extra-openai-models.yaml;
    force = true;
  };

  home.file.".config/io.datasette.llm/extra-openai-models.yaml" = {
    enable = pkgs.stdenv.isLinux;
    source = config.lib.file.mkOutOfStoreSymlink ./extra-openai-models.yaml;
    force = true;
  };
}
