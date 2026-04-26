{ inputs }:
let
  inherit (inputs.host) isDesktop;
in
[
  ./aichat
  ./amp
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
  ./iterm2
  ./hammerspoon
  ./jj
  ./k3s
  ./kube
  ./karabiner
  ./llm
  ./mempalace
  ./obsidian
  ./omp
  ./openclaw
  ./opencode
  ./paperclip
  ./pi
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
      ./hyprpanel
      ./hyprshell
      ./nwg-dock-hyprland
      ./nwg-drawer
      ./rofi
    ]
  else
    [ ]
)
