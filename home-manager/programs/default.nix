{
  lib,
  pkgs,
  sources,
}:
let
  bat = import ./bat;
  direnv = import ./direnv;
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
  python = import ./python;
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
  direnv
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
  python
  rust
  ssh
  starship
  tms
  tmux
  zoxide
  zsh
]
