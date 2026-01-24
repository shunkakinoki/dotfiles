# Clawdbot hydrate script with injected Nix store paths
{ pkgs, inputs }:
let
  clawdbotPkg = inputs.nix-clawdbot.packages.${pkgs.system}.clawdbot;
  templateFile = ./clawdbot.template.json;
in
pkgs.replaceVars ./hydrate.sh {
  template = templateFile;
  sed = "${pkgs.gnused}/bin/sed";
  chromium = pkgs.chromium;
  clawdbot = clawdbotPkg;
}
