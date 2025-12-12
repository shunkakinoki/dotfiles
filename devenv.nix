{ pkgs }:

{
  packages = [
    pkgs.nodejs
    pkgs.bun
    pkgs.neovim
    pkgs.shellspec
  ];

  containers = pkgs.lib.mkIf (!pkgs.stdenv.hostPlatform.isLinux) (pkgs.lib.mkForce { });

  enterShell = ''
    echo "Dev shell ready: Node.js, bun, and Neovim available."
  '';
}
