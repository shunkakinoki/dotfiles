{
  lib,
  pkgs,
  sources,
}:
let
  bash = import ./bash { inherit lib pkgs; };
  bat = import ./bat;
  direnv = import ./direnv;
  fd = import ./fd;
  fish = import ./fish;
  fnm = import ./fnm { inherit pkgs; };
  fzf = import ./fzf;
  gh = import ./gh;
  ghq = import ./ghq;
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
  zig = import ./zig;
  zoxide = import ./zoxide;
  zsh = import ./zsh { inherit lib pkgs; };
in
[
  bash
  bat
  direnv
  fd
  fish
  fnm
  fzf
  gh
  ghq
  git
  go
  lazygit
  lsd
  neovim
  python
  rust
  ssh
  zig
  starship
  tms
  tmux
  zoxide
  zsh
]
