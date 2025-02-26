{
  lib,
  pkgs,
  sources,
}:
let
  bat = import ./bat;
  fd = import ./fd;
  fish = import ./fish;
  fzf = import ./fzf;
  gh = import ./gh;
  go = import ./go;
  lazygit = import ./lazygit;
  lsd = import ./lsd;
  neovim = import ./neovim;
  rust = import ./rust;
  ssh = import ./ssh;
  starship = import ./starship;
  tmux = import ./tmux;
  zoxide = import ./zoxide;
  zsh = import ./zsh { inherit lib pkgs; };
in
[
  bat
  fd
  fish
  fzf
  gh
  go
  lazygit
  lsd
  neovim
  rust
  ssh
  starship
  tmux
  zoxide
  zsh
]
