{ pkgs }:

{
  packages = [
    pkgs.nodejs
    pkgs.bun
    pkgs.neovim
  ];

  enterShell = ''
    echo "Dev shell ready: Node.js, bun, and Neovim available."
  '';
}