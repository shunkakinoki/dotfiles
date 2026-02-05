{
  pkgs,
  lib,
  inputs,
}:
let
  env = import ../lib/env.nix;
  host = import ../lib/host.nix;
  nixpkgsConfig = import ../lib/nixpkgs-config.nix {
    nixpkgsLib = inputs.nixpkgs.lib;
  };
  mockPkg = name: {
    pname = name;
    inherit name;
  };
in
{
  lib-env = pkgs.runCommand "lib-env" { } ''
    ${
      if env ? isCI && builtins.isBool env.isCI then
        ''echo "lib/env.nix: isCI is a boolean (value: ${builtins.toString env.isCI})"''
      else
        ''echo "FAIL: env.isCI must exist and be a boolean" && exit 1''
    }
    touch $out
  '';

  lib-host = pkgs.runCommand "lib-host" { } ''
    ${
      if host ? isKyber && builtins.isBool host.isKyber then
        ''echo "lib/host.nix: isKyber is a boolean"''
      else
        ''echo "FAIL: host.isKyber must exist and be a boolean" && exit 1''
    }
    ${
      if host ? isGalactica && builtins.isBool host.isGalactica then
        ''echo "lib/host.nix: isGalactica is a boolean"''
      else
        ''echo "FAIL: host.isGalactica must exist and be a boolean" && exit 1''
    }
    ${
      if host ? isMatic && builtins.isBool host.isMatic then
        ''echo "lib/host.nix: isMatic is a boolean"''
      else
        ''echo "FAIL: host.isMatic must exist and be a boolean" && exit 1''
    }
    ${
      if host ? nodeName && builtins.isString host.nodeName then
        ''echo "lib/host.nix: nodeName is a string (value: ${host.nodeName})"''
      else
        ''echo "FAIL: host.nodeName must exist and be a string" && exit 1''
    }
    ${
      if host ? isDesktop && builtins.isBool host.isDesktop then
        ''echo "lib/host.nix: isDesktop is a boolean (value: ${builtins.toString host.isDesktop})"''
      else
        ''echo "FAIL: host.isDesktop must exist and be a boolean" && exit 1''
    }
    touch $out
  '';

  lib-nixpkgs-config = pkgs.runCommand "lib-nixpkgs-config" { } ''
    ${
      if nixpkgsConfig ? allowUnfree && nixpkgsConfig.allowUnfree == true then
        ''echo "lib/nixpkgs-config.nix: allowUnfree is true"''
      else
        ''echo "FAIL: allowUnfree must be true" && exit 1''
    }
    ${
      if nixpkgsConfig ? allowUnfreePredicate then
        ''echo "lib/nixpkgs-config.nix: allowUnfreePredicate exists"''
      else
        ''echo "FAIL: allowUnfreePredicate must exist" && exit 1''
    }
    touch $out
  '';

  lib-nixpkgs-unfree-predicate = pkgs.runCommand "lib-nixpkgs-unfree-predicate" { } ''
    ${lib.concatMapStringsSep "\n"
      (
        name:
        let
          allowed = nixpkgsConfig.allowUnfreePredicate (mockPkg name);
        in
        if allowed then
          ''echo "${name} is allowed by unfree predicate"''
        else
          ''echo "FAIL: ${name} should be allowed by unfree predicate" && exit 1''
      )
      [
        "1password"
        "claude-code"
        "clickup"
        "crush"
        "qwen-code"
        "slack"
      ]
    }
    touch $out
  '';
}
