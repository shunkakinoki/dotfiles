{
  lib,
  pkgs,
  ...
}:
let
  atuin = import ./atuin;
  bash = import ./bash { inherit lib pkgs; };
  bat = import ./bat;
  btop = import ./btop;
  cass = import ./cass;
  clang = import ./clang;
  dart = import ./dart;
  delta = import ./delta;
  direnv = import ./direnv;
  elixir = import ./elixir;
  fd = import ./fd;
  fish = import ./fish;
  fnm = import ./fnm;
  fzf = import ./fzf;
  gh = import ./gh { inherit pkgs; };
  ghq = import ./ghq;
  git = import ./git;
  go = import ./go;
  haskell = import ./haskell;
  java = import ./java;
  kotlin = import ./kotlin;
  lazydocker = import ./lazydocker;
  lazygit = import ./lazygit;
  lsd = import ./lsd;
  lua = import ./lua;
  neovim = import ./neovim;
  nvtop = import ./nvtop;
  nix = import ./nix;
  node = import ./node;
  ocaml = import ./ocaml;
  perl = import ./perl;
  php = import ./php;
  python = import ./python;
  ruby = import ./ruby;
  rust = import ./rust;
  ssh = import ./ssh;
  starship = import ./starship;
  swift = import ./swift;
  terraform = import ./terraform;
  tms = import ./tms;
  tmux = import ./tmux;
  yaml = import ./yaml;
  yazi = import ./yazi;
  zig = import ./zig;
  zoxide = import ./zoxide;
  zsh = import ./zsh;
in
[
  atuin
  bash
  bat
  btop
  cass
  clang
  dart
  delta
  direnv
  elixir
  fd
  fish
  fnm
  fzf
  gh
  ghq
  git
  go
  haskell
  java
  kotlin
  lazydocker
  lazygit
  lsd
  lua
  neovim
  nvtop
  nix
  node
  ocaml
  perl
  php
  python
  ruby
  rust
  ssh
  starship
  swift
  terraform
  tms
  tmux
  yaml
  yazi
  zig
  zoxide
  zsh
]
