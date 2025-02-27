{
  lib,
  pkgs,
  sources,
}:
let
  bat = import ./bat;
  fd = import ./fd;
  fish = import ./fish;
  fnm = import ./fnm { inherit pkgs; };
  fzf = import ./fzf;
  gh = import ./gh;
  git = import ./git;
  go = import ./go;
  lazygit = import ./lazygit;
  lsd = import ./lsd;
  neovim = import ./neovim;
  rust = import ./rust;
  ssh = import ./ssh;
  starship = import ./starship;
  tms = import ./tms;
  tmux = import ./tmux;
  zoxide = import ./zoxide;
  zsh = import ./zsh { inherit lib pkgs; };
in
[
  bat
  fd
  fish
  fnm
  fzf
  gh
  git
  go
  lazygit
  lsd
  neovim
  rust
  ssh
  starship
  tms
  tmux
  zoxide
  zsh
]
