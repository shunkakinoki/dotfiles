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
  ./ghostty
  ./iterm2
  ./hammerspoon
  ./jj
  ./k3s
  ./karabiner
  ./llm
  ./openclaw
  ./opencode
  ./pi
  ./serena
  ./starship
  ./worktrunk
  ./zellij
]
++ (
  if isDesktop then
    [
      ./gtk
      ./hyprland
      ./hyprpanel
      ./rofi
      ./walker
    ]
  else
    [ ]
)
