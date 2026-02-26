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
    (pkgs.writeShellScriptBin "fishtape" ''
      exec ${pkgs.fish}/bin/fish \
        -C "source ${pkgs.fishPlugins.fishtape_3.src}/functions/fishtape.fish" \
        -c 'fishtape $argv' \
        -- "$@"
    '')
  ];

  containers = pkgs.lib.mkIf (!pkgs.stdenv.hostPlatform.isLinux) (pkgs.lib.mkForce { });

  enterShell = ''
    echo "Dev shell ready: Node.js, bun, and Neovim available."
  '';
}
