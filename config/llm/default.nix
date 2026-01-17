{ config, ... }:
{
  home.file.".config/io.datasette.llm/extra-openai-models.yaml" = {
    source = config.lib.file.mkOutOfStoreSymlink ./extra-openai-models.yaml;
    force = true;
  };
}
