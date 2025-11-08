{
  lib,
  pkgs,
  sources,
}:
let
  atuin = import ./atuin;
  bash = import ./bash { inherit lib pkgs; };
  bat = import ./bat;
  delta = import ./delta;
  direnv = import ./direnv;
  fd = import ./fd;
  fish = import ./fish;
  fnm = import ./fnm { inherit pkgs; };
  fzf = import ./fzf;
  gh = import ./gh;
  ghq = import ./ghq;
  git = import ./git;
  go = import ./go;
  lazydocker = import ./lazydocker;
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
  atuin
  bash
  bat
  delta
  direnv
  fd
  fish
  fnm
  fzf
  gh
  ghq
  git
  go
  lazydocker
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
