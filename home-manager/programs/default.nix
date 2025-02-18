{
  lib,
  pkgs,
  sources,
}:
let
  fd = import ./fd;
  fish = import ./fish;
  fzf = import ./fzf;
  gh = import ./gh;
  go = import ./go;
  neovim = import ./neovim;
  rust = import ./rust;
  ssh = import ./ssh;
  starship = import ./starship;
  tmux = import ./tmux;
  zsh = import ./zsh { inherit lib pkgs; };
in
[
  fd
  fish
  fzf
  gh
  go
  neovim
  rust
  ssh
  starship
  tmux
  zsh
]
