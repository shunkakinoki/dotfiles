# Upgrading patched packages

`make bun-update` updates unpatched packages and preserves the existing lockfile.
Renovate leaves patched packages to a manual upgrade. Keep its exclusion list
in sync when adding a new patched package; the patch tests enforce this.

For a patched upgrade:

1. Obtain the published target package and check whether upstream fixed each
   patched behavior. Find renamed bundles by their code and actual hunk
   application, rather than guessing their hashed filenames.
2. Prepare the target with `bun patch <package>@<version>`, port the retained
   changes, and generate the patch with `bun patch --commit node_modules/<package>`.
3. Update the exact dependency pin, patch key and patch filename together.
   Remove obsolete declarations, then run `bun install` and retain `bun.lock`.
4. Run `bun test ./tests/package-patches.test.ts` and `make patches-check`.
   The latter installs only the patched packages into a temporary directory
   with lifecycle scripts disabled, checks installed versions and every patch
   postimage, then checks a frozen install. It leaves the working install intact.
5. Exercise the original bug and relevant repository checks. Postimage checks
   establish application, not complete runtime correctness. For OpenClaw,
   verify the worker heap settings and the affected state-worker behavior.
6. Review and commit the manifest, patch and lockfile as one upgrade.

Package-patch CI runs on pull requests. Global activation checks the same
metadata and installed postimages and fails if patch application fails.
Do not run activation or switch a host merely to validate an upgrade PR.
