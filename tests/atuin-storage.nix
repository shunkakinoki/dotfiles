{ pkgs }:
{
  atuin-startup-prevention =
    pkgs.runCommand "atuin-startup-prevention"
      {
        nativeBuildInputs = [
          pkgs.bun
          pkgs.atuin
          pkgs.fish
          pkgs.coreutils
          pkgs.bash
        ]
        ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.systemd ];
      }
      ''
        export HOME="$TMPDIR"
        export ATUIN_TEST_BIN="${pkgs.atuin}/bin/atuin"
        mkdir -p tests home-manager/programs/atuin config/k3s
        cp ${./atuin-startup.test.ts} tests/atuin-startup.test.ts
        cp ${../home-manager/programs/atuin/hook-client.sh} home-manager/programs/atuin/hook-client.sh
        cp ${../config/k3s/atuin-storage-guard.sh} config/k3s/atuin-storage-guard.sh
        cp ${../config/k3s/kyber-host-health.sh} config/k3s/kyber-host-health.sh
        bun test tests/atuin-startup.test.ts
        touch "$out"
      '';
  atuin-storage-preservation =
    pkgs.runCommand "atuin-storage-preservation"
      {
        nativeBuildInputs = [ pkgs.bun ];
      }
      ''
        export HOME="$TMPDIR"
        mkdir -p scripts tests
        cp ${../scripts/atuin-storage.ts} scripts/atuin-storage.ts
        cp ${./atuin-storage.test.ts} tests/atuin-storage.test.ts
        bun test ./tests/atuin-storage.test.ts
        touch "$out"
      '';
}
