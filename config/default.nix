{ inputs }:
let
  inherit (inputs.host) isDesktop;
in
[
  ./aichat
  ./amp
  ./bun
  ./ccs
  ./cliproxyapi
  ./codex
  ./crush
  ./cursor
  ./claude
  ./direnv
  ./factory
  ./gemini
  ./git-ai
  ./gomi
  ./ghostty
  ./hermes
  ./iterm2
  ./hammerspoon
  ./jj
  ./k3s
  ./karabiner
  ./llm
  ./mempalace
  ./npm
  ./obsidian
  ./omp
  ./openclaw
  ./opencode
  ./paperclip
  ./pi
  ./pnpm
  ./serena
  ./starship
  ./tmuxinator
  ./worktrunk
  ./zellij
]
++ (
  if isDesktop then
    [
      ./eww
      ./gtk
      ./hyprland
      ./noctalia
      ./hyprshell
      ./nwg-drawer
    ]
  else
    [ ]
)
