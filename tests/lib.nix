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
  lib-kamino-shortcuts =
    let
      kamino = import ../home-manager/programs/kamino { inherit lib pkgs; };
      fish = kamino.programs.fish;
      fleet = import ../named-hosts/kamino/fleet.nix { };
      functions = pkgs.writeText "kamino-shortcuts.fish" (
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: value: ''
            function ${name}
              ${value.body}
            end
          '') fish.functions
        )
        + "\nsource ${./kamino-shortcuts.fish} $argv\n"
      );
    in
    assert builtins.length (builtins.attrNames fish.shellAbbrs) == 5 * builtins.length fleet.machines;
    assert lib.all (name: builtins.hasAttr name fish.functions) (builtins.attrValues fish.shellAbbrs);
    pkgs.runCommand "lib-kamino-shortcuts" { nativeBuildInputs = [ pkgs.fish ]; } ''
      fish --no-config ${functions} ${lib.escapeShellArgs (map (machine: machine.name) fleet.machines)}
      touch "$out"
    '';

  lib-kamino-fleet =
    let
      fleet = import ../named-hosts/kamino/fleet.nix { count = 100; };
      first = builtins.elemAt fleet.machines 0;
      last = builtins.elemAt fleet.machines 100;
      names = map (machine: machine.name) fleet.machines;
    in
    assert builtins.length fleet.machines == 101;
    assert first.name == "kamino";
    assert last.name == "kamino100";
    assert last.hostname == "kamino100.tail950b36.ts.net";
    assert last.user == "root";
    assert builtins.length (lib.unique names) == 101;
    pkgs.runCommand "lib-kamino-fleet" { } ''
      touch $out
    '';

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
      if host ? isAndor && builtins.isBool host.isAndor then
        ''echo "lib/host.nix: isAndor is a boolean"''
      else
        ''echo "FAIL: host.isAndor must exist and be a boolean" && exit 1''
    }
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
      if host ? isViper && builtins.isBool host.isViper then
        ''echo "lib/host.nix: isViper is a boolean"''
      else
        ''echo "FAIL: host.isViper must exist and be a boolean" && exit 1''
    }
    ${
      if host ? nodeName && builtins.isString host.nodeName then
        ''echo "lib/host.nix: nodeName is a string (value: ${host.nodeName})"''
      else
        ''echo "FAIL: host.nodeName must exist and be a string" && exit 1''
    }
    ${
      if host ? isK3sServer && builtins.isBool host.isK3sServer then
        ''echo "lib/host.nix: isK3sServer is a boolean"''
      else
        ''echo "FAIL: host.isK3sServer must exist and be a boolean" && exit 1''
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
      if nixpkgsConfig ? allowUnfree && nixpkgsConfig.allowUnfree then
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
