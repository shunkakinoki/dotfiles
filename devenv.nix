{ pkgs, devenv-pkg }:

{
  packages = [
    pkgs.nodejs
    pkgs.bun
    pkgs.neovim
    devenv-pkg
  ];

  enterShell = ''
    echo "Dev shell ready: Node.js, bun, and Neovim available."
  '';
}