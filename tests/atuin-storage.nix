{ pkgs }:
{
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
