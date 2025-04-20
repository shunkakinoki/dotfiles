{ pkgs, ... }:

{
  services.docker.enable = true;
  #   services.docker.enableNvidia = false;

  services.docker.containers.openwebui = {
    image = "ghcr.io/open-webui/open-webui:main";
    workingDir = "/app/backend";
    ports = [ "3000:8080" ];
    volumes = [ "open-webui:/app/backend/data" ];
    extraHosts = [ "host.docker.internal:host-gateway" ];
    environment = {
      LANG = "C.UTF-8";
      GPG_KEY = "A035C8C19219BA821ECEA86B64E628F8D684696D";
      PYTHON_VERSION = "3.11.11";
      PYTHON_SHA256 = "2a9920c7a0cd236de33644ed980a13cbbc21058bfdc528febb6081575ed73be3";
      ENV = "prod";
      PORT = "8080";
      USE_OLLAMA_DOCKER = "false";
      USE_CUDA_DOCKER = "false";
      USE_CUDA_DOCKER_VER = "cu121";
      USE_EMBEDDING_MODEL_DOCKER = "sentence-transformers/all-MiniLM-L6-v2";
      USE_RERANKING_MODEL_DOCKER = "";
      OLLAMA_BASE_URL = "/ollama";
      OPENAI_API_BASE_URL = "";
      SCARF_NO_ANALYTICS = "true";
      DO_NOT_TRACK = "true";
      ANONYMIZED_TELEMETRY = "false";
      WHISPER_MODEL = "base";
      WHISPER_MODEL_DIR = "/app/backend/data/cache/whisper/models";
      RAG_EMBEDDING_MODEL = "sentence-transformers/all-MiniLM-L6-v2";
      RAG_RERANKING_MODEL = "";
      SENTENCE_TRANSFORMERS_HOME = "/app/backend/data/cache/embedding/models";
      TIKTOKEN_ENCODING_NAME = "cl100k_base";
      TIKTOKEN_CACHE_DIR = "/app/backend/data/cache/tiktoken";
      HF_HOME = "/app/backend/data/cache/embedding/models";
      WEBUI_BUILD_VERSION = "b03fc97e287f31ad07bda896143959bc4413f7d2";
      DOCKER = "true";
    };
    extraOptions = [ "--restart=always" ];
  };
}
