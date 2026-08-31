{
  config,
  pkgs,
  ...
}:
let
  hydrateScript = pkgs.writeText "llm-hydrate.sh" (
    builtins.replaceStrings [ "@jq@" "@yq@" ] [ "${pkgs.jq}/bin/jq" "${pkgs.yq}/bin/yq" ] (
      builtins.readFile ./hydrate.sh
    )
  );
in
{
  home.file."Library/Application Support/io.datasette.llm/extra-openai-models.yaml" = {
    enable = pkgs.stdenv.hostPlatform.isDarwin;
    source = ./extra-openai-models.yaml;
    force = true;
  };

  home.file."Library/Application Support/io.datasette.llm/default_model.txt" = {
    enable = pkgs.stdenv.hostPlatform.isDarwin;
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

  # LLM extra models only support stored key aliases, so keep the existing
  # cliproxyapi alias synchronized from the shared CLIProxy credential.
  home.activation.hydrateLlmCliproxyKey = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash "${hydrateScript}" || true
  '';
}
