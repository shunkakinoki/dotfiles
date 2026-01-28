{ config, pkgs, ... }:
{
  home.file."Library/Application Support/io.datasette.llm/extra-openai-models.yaml" = {
    enable = pkgs.stdenv.isDarwin;
    source = ./extra-openai-models.yaml;
    force = true;
  };

  home.file."Library/Application Support/io.datasette.llm/default_model.txt" = {
    enable = pkgs.stdenv.isDarwin;
    source = ./default_model.txt;
    force = true;
  };

  home.file.".config/io.datasette.llm/extra-openai-models.yaml" = {
    enable = pkgs.stdenv.isLinux;
    source = ./extra-openai-models.yaml;
    force = true;
  };

  home.file.".config/io.datasette.llm/default_model.txt" = {
    enable = pkgs.stdenv.isLinux;
    source = ./default_model.txt;
    force = true;
  };
}
