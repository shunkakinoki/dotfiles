{
  lib,
  pkgs,
  sources,
}:
let
  fish = import ./fish;
  gh = import ./gh;
  go = import ./go;
  rust = import ./rust;
  ssh = import ./ssh;
  starship = import ./starship;
  tmux = import ./tmux;
  zsh = import ./zsh { inherit lib pkgs; };
in
[
  fish
  gh
  go
  rust
  ssh
  starship
  tmux
  zsh
]
