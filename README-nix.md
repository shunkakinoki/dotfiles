# Nix + dream2nix setup

This repo can build and expose all CLI tools declared in `package.json` using the exact versions from the lockfile, via [dream2nix].

## Prerequisites
- Nix installed
- Flakes enabled (see Nix docs)

## Typical usage

Build the tools as a package:
```bash
nix build .#node-tools
# The result symlink contains bin/ with your CLI tools
ls -l result/bin
```

Open a dev shell with Node and tools on PATH:

```bash
nix develop
# then run your tools, e.g.
tsc --version
prettier --version
eslint_d --version
```

Use in Home Manager (example):

```nix
{ pkgs, ... }:
{
  home.packages = [
    (builtins.getFlake ".").packages.${builtins.currentSystem}.node-tools
  ];
}
```

## Notes

* Versions are pinned by the lockfile (`bun.lockb`).
* If you change dependencies, update the lockfile, then rebuild.
* If your package has native deps, dream2nix will build them; ensure required system libs are available in nixpkgs.

## Troubleshooting

* **Missing lockfile**: generate one (`bun install`) before running `nix build`.
* **Postinstall script fails**: check logs from `nix build`; you may need to add system libraries or patch scripts.
* **Bins missing**: ensure the dependency actually exposes a `bin` entry in its `package.json`.

[dream2nix]: https://github.com/nix-community/dream2nix

