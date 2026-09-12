{ pkgs }:
pkgs.writeShellApplication {
  name = "find";
  runtimeInputs = [ pkgs.coreutils ];
  text = ''
    exec ${pkgs.bash}/bin/bash ${./find.sh} ${pkgs.findutils}/bin/find "$@"
  '';
}
