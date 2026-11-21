{ pkgs }:
{
  overlay-codex-crypto =
    assert pkgs.codex.env.OPENSSL_LIB_DIR == "${pkgs.openssl.out}/lib";
    assert pkgs.codex.env.OPENSSL_INCLUDE_DIR == "${pkgs.openssl.dev}/include";
    pkgs.runCommand "overlay-codex-crypto" { } ''
      prefix=${pkgs.codex.env.AWS_LC_SYS_SYSTEM_DIR}
      test -f "$prefix/include/openssl/base.h" || test -f "$prefix/include/aws-lc/openssl/base.h"
      test -f "$prefix/lib/libcrypto-awslc.${if pkgs.stdenv.hostPlatform.isDarwin then "dylib" else "so"}"
      test -f "$prefix/share/rust/aws_lc_bindings.rs"
      touch $out
    '';

  overlay-neovim-lua = pkgs.runCommand "overlay-neovim-lua" { } ''
    ${
      if pkgs.neovim-unwrapped ? lua then
        ''echo "neovim-unwrapped has lua attribute"''
      else
        ''echo "FAIL: neovim-unwrapped missing lua attribute" && exit 1''
    }
    touch $out
  '';

  # programs.neovim / devenv use pkgs.neovim, which neovim-nightly keeps distinct
  # from neovim-unwrapped. Both must skip flaky functional tests on cache miss.
  overlay-neovim-nocheck = pkgs.runCommand "overlay-neovim-nocheck" { } ''
    ${
      if !(pkgs.neovim.doCheck or true) && !(pkgs.neovim-unwrapped.doCheck or true) then
        ''echo "neovim and neovim-unwrapped have doCheck=false"''
      else
        ''echo "FAIL: expected doCheck=false on neovim and neovim-unwrapped" && exit 1''
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
