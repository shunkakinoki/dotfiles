{ pkgs }:

{
  packages = [
    pkgs.nodejs
    pkgs.bun
    pkgs.neovim
    pkgs.shellcheck
    pkgs.shellspec
    pkgs.gnumake
    pkgs.gcc
    pkgs.fish
    pkgs.statix
    (pkgs.writeShellScriptBin "fishtape" (
      builtins.readFile (
        pkgs.replaceVars ./scripts/fishtape-wrapper.sh {
          fish = pkgs.fish;
          fishtape_3_src = pkgs.fishPlugins.fishtape_3.src;
        }
      )
    ))
  ];

  containers = pkgs.lib.mkIf (!pkgs.stdenv.hostPlatform.isLinux) (pkgs.lib.mkForce { });

  enterShell = ''
    echo "Dev shell ready: Node.js, bun, and Neovim available."
  '';
}
