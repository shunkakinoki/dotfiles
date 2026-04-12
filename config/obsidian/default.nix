{
  config,
  inputs,
  pkgs,
  ...
}:
let
  inherit (inputs.host) isKyber isGalactica;
  enabled = isKyber || isGalactica;
  obsidianJson = pkgs.writeText "obsidian.json" (
    builtins.toJSON {
      cli = true;
      vaults.wiki = {
        path = "${config.home.homeDirectory}/ghq/github.com/shunkakinoki/wiki";
        ts = 0;
        open = true;
      };
    }
  );
in
{
  xdg.configFile."obsidian/obsidian.json" = {
    source = obsidianJson;
    enable = enabled;
  };
}
