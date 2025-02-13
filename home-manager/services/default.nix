{ pkgs }:
let
  ollamaModule = import ./ollama { inherit pkgs; };
in
[
  ollamaModule
]
