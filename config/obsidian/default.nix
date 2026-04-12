{
  inputs,
  ...
}:
let
  inherit (inputs.host) isKyber;
in
{
  xdg.configFile."obsidian/obsidian.json" = {
    source = ./obsidian.json;
    enable = isKyber;
  };
}
