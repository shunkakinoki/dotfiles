# Dependency Upgrade Log

**Date:** 2026-08-31
**Languages:** Nix, JavaScript, Python, Rust, GitHub Actions
**Manifests:** `flake.nix`, `flake.lock`, `package.json`, `bun.lock`, `pyproject.toml`, `Cargo.toml`, `.github/workflows/*`

## Policy

- Target the newest stable release available at execution time. The user explicitly overrode the repository's seven-day minimum release age for this sweep.
- Preserve intentional prerelease channels, while advancing branch dependencies and exact platform packages through their owning update workflows.
- Treat submodules as separately owned repositories and advance the gitlink to the current upstream default-branch head.

## Summary

| Metric | Count |
| --- | ---: |
| Dependency surfaces audited | 7 |
| JavaScript declarations updated | 54 |
| Python declarations updated | 13 |
| Custom overlays updated | 3 |
| Failed and rolled back | 0 |
| New security advisories | 0 |

## Updates

### JavaScript and Bun

- Updated Claude Code and all eight matching optional platform packages from 2.1.239 to 2.1.251.
- Updated Codex and all six matching optional platform packages from 0.149.0 to 0.151.0.
- Updated Oh My Pi packages from 17.4.2 to 18.0.11.
- Updated every other direct Bun dependency with a newer release, including PostHog CLI 0.16.0, Cline 3.0.60, gh-axi 0.1.35, mcp-remote 0.8.2, OpenClaw 2026.8.1, and Takt 0.63.0.
- Regenerated `bun.lock` and verified frozen installation plus CLI smoke tests.

### Python tools

- Updated agentsview to 0.41.1, claude-swap to 0.25.0, git-remote-s3 to 0.4.2, graphifyy to 0.9.53, and huggingface-hub to 1.29.0.
- Updated mempalace to 3.8.0, mistral-vibe to 2.24.5, Ruff to 0.16.5, serena-agent to 1.7.0, transformers to 5.16.1, and vLLM to 0.28.0.
- Updated the Hermes runtime constraints for FastAPI to 0.141.1 and Uvicorn to 0.52.4.
- Resolved every direct tool independently with `uv pip compile --no-deps` before running the repository tests and lint checks.

### Nix and generated upstreams

- Refreshed the flake lock graph for the floating inputs, including nixpkgs channels, Home Manager, nix-darwin, flake-parts, devenv, treefmt, NUR, hardware modules, Foundry, Handy, LLM agents, and Neovim nightly.
- Updated the Moshi Hook overlay from 0.3.3 to 0.3.15 and Crabbox from 0.46.0 to 0.47.0 with hashes for all four supported OS/architecture combinations.
- Advanced the GitHub CLI preview overlay to the August 28 upstream trunk head and refreshed its source and Go vendor hashes.
- Regenerated the Moshi adapters, followed the upstream Oh My Pi extension path move, and normalized machine-local binary paths to portable command names.
- Removed the external Noctalia Home Manager module import because current Home Manager now supplies the same module; the pinned input remains the package source.
- Made the Blacksmith overlay updater select the correct probe binary for the host OS and architecture.
- Added CMake to mise's native build inputs because 2026.8.6 now compiles `libz-ng-sys` from source.
- Disabled Vector 0.58.0's package check phase on Darwin after three independent timing-sensitive tests failed across otherwise-green runs of more than 2,400 tests; repository Nix evaluation and full system-build checks remain enabled.
- Guarded the legacy t3code pnpm dependency hash override so refreshed llm-agents packages that no longer expose `pnpmDeps` continue to evaluate on Linux.
- Routed Handy and its bun2nix input through the current `nixpkgs-26.05-darwin` compatibility branch because they still expose `x86_64-darwin`, which root nixpkgs no longer supports.
- Added systemd's libudev runtime to the Foundry binary overlay after the refreshed nightly introduced that Linux dependency without declaring it upstream.

## Skipped or Preserved

- Updated Worktrunk from 0.74.0 to 0.75.0, refreshed all Cargo transitive dependencies, and advanced the Git-backed git-ai and rtk dependencies to their current branch heads.
- Updated Renovate's GitHub Action from 46.1.21 to 46.2.5 and advanced the dotagents submodule to the current upstream default-branch head.
- Preserved intentional prerelease channels; Yek and the remaining direct Python dependencies were already at their newest releases.

## Validation

- `bun install --frozen-lockfile`
- CLI version smoke tests for every updated JavaScript tool
- `uv run --with pytest --no-project pytest tests` (8 passed)
- `uv run --with ruff --no-project ruff check`
- `uv run --with ruff --no-project ruff format --check --diff`
- `cargo test`
- `make nix-format-check`
- `make nix-lint`
- `make nix-test`
- `CI=true make nix-build`
- `make shell-check`
- `nix fmt` for changed generated/configuration files
- `git diff --check`

The repository's Darwin `nix-flake-check` wrapper successfully completed all host-native checks. Its additional Linux checks cannot build `x86_64-linux` Docker service derivations on an `aarch64-darwin` machine without a compatible remote builder; the same configurations were evaluated by `make nix-test`.

## Security Notes

`bun audit` reports 37 transitive advisories (1 critical, 15 high, 17 moderate, and 4 low) across 10 package names. `bun audit fix` could not advance them past their upstream dependency ranges. An isolated audit of the pre-upgrade lockfile produced the same 37 advisory identifiers and affected-package set, so this upgrade introduces zero new advisories.

## Commands Used

- `bun update --latest --minimum-release-age=0`, `bun install --frozen-lockfile --minimum-release-age=0`, `bun audit`
- `uv pip compile --no-deps --exclude-newer 2100-01-01`, `uv run pytest`, `uv run ruff`
- `cargo update`, `cargo test`
- `nix flake update`, `nix fmt`, repository Nix checks and build
- repository overlay and generated-hook update targets
- GitHub API release and action-ref audits
