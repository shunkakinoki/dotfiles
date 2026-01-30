{
  pkgs,
  lib,
  inputs,
}:
{
  overlay-neovim-lua = pkgs.runCommand "overlay-neovim-lua" { } ''
    ${
      if pkgs.neovim-unwrapped ? lua then
        ''echo "neovim-unwrapped has lua attribute"''
      else
        ''echo "FAIL: neovim-unwrapped missing lua attribute" && exit 1''
    }
    touch $out
  '';

  overlay-system-alias = pkgs.runCommand "overlay-system-alias" { } ''
    ${
      if pkgs ? system && builtins.isString pkgs.system then
        ''echo "pkgs.system exists: ${pkgs.system}"''
      else
        ''echo "FAIL: pkgs.system must exist and be a string" && exit 1''
    }
    touch $out
  '';

  overlay-shellspec = pkgs.runCommand "overlay-shellspec" { } ''
    test -e ${pkgs.shellspec}/bin/shellspec && echo "shellspec binary exists"
    touch $out
  '';
}
