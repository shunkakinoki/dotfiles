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
  ./ghostty
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
  ./zellij
]
++ (
  if isDesktop then
    [
      ./gtk
      ./hyprland
      ./hyprpanel
      ./walker
    ]
  else
    [ ]
)
