import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

type Manifest = {
  version?: string;
  dependencies?: Record<string, string>;
  optionalDependencies?: Record<string, string>;
  overrides?: Record<string, string>;
  patchedDependencies?: Record<string, string>;
};

export function patchedPackages(manifest: Manifest) {
  return Object.entries(manifest.patchedDependencies ?? {}).map(([specifier, path]) => {
    const separator = specifier.lastIndexOf("@");
    if (separator <= 0 || separator === specifier.length - 1)
      throw new Error(`Invalid patch key: ${specifier}`);
    return {
      specifier,
      path,
      name: specifier.slice(0, separator),
      version: specifier.slice(separator + 1),
    };
  });
}

function manifestAt(root: string): Manifest {
  return JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
}

export function checkPatches(root: string) {
  const manifest = manifestAt(root);
  const lock = Bun.JSONC.parse(readFileSync(join(root, "bun.lock"), "utf8"));
  const patches = patchedPackages(manifest);
  const expected = manifest.patchedDependencies ?? {};
  const actual = lock.patchedDependencies ?? {};
  if (
    Object.keys(expected).length !== Object.keys(actual).length ||
    Object.entries(expected).some(([key, path]) => actual[key] !== path)
  ) {
    throw new Error(
      "Patch declarations differ in package.json and bun.lock; run bun install after porting patches",
    );
  }
  for (const patch of patches) {
    if (manifest.dependencies?.[patch.name] !== patch.version) {
      throw new Error(
        `${patch.name} must be pinned to its patch version ${patch.version}; port the patch before upgrading`,
      );
    }
    if (!existsSync(join(root, patch.path))) throw new Error(`Missing patch: ${patch.path}`);
    const entry = lock.packages?.[patch.name];
    if (entry?.[0] !== patch.specifier)
      throw new Error(`Lockfile does not resolve ${patch.specifier}`);
  }
  return patches;
}

export function updateablePackages(manifest: Manifest): string[] {
  const held = new Set(patchedPackages(manifest).map((patch) => patch.name));
  return [
    ...new Set([
      ...Object.keys(manifest.dependencies ?? {}),
      ...Object.keys(manifest.optionalDependencies ?? {}),
    ]),
  ].filter((name) => !held.has(name));
}

function run(command: string[], cwd: string) {
  const result = Bun.spawnSync(command, { cwd, stdout: "inherit", stderr: "inherit" });
  if (result.exitCode !== 0)
    throw new Error(`${command[0]} ${command[1]} failed (${result.exitCode})`);
}

export function checkInstalled(root: string, installedRoot: string) {
  for (const patch of checkPatches(root)) {
    const directory = join(installedRoot, "node_modules", patch.name);
    if (manifestAt(directory).version !== patch.version)
      throw new Error(`Installed ${patch.name} does not match ${patch.version}`);
    // Reverse application proves every hunk's postimage exists in the installed package.
    run(
      ["git", "apply", "--reverse", "--check", "--ignore-space-change", resolve(root, patch.path)],
      directory,
    );
  }
}

export function verifyCleanInstall(root: string) {
  const patches = checkPatches(root);
  const scratch = mkdtempSync(join(tmpdir(), "package-patches-"));
  try {
    for (const patch of patches) {
      mkdirSync(dirname(join(scratch, patch.path)), { recursive: true });
      cpSync(join(root, patch.path), join(scratch, patch.path));
    }
    const manifest = manifestAt(root);
    writeFileSync(
      join(scratch, "package.json"),
      JSON.stringify({
        private: true,
        dependencies: Object.fromEntries(patches.map((patch) => [patch.name, patch.version])),
        patchedDependencies: manifest.patchedDependencies,
        overrides: manifest.overrides,
      }),
    );
    run([process.execPath, "install", "--ignore-scripts"], scratch);
    checkInstalled(root, scratch);
    run([process.execPath, "install", "--frozen-lockfile", "--ignore-scripts"], scratch);
  } finally {
    rmSync(scratch, { recursive: true, force: true });
  }
}

if (import.meta.main) {
  const root = resolve(import.meta.dir, "..");
  const command = process.argv[2] ?? "check";
  if (command === "check") checkPatches(root);
  else if (command === "verify") verifyCleanInstall(root);
  else if (command === "installed" && process.argv[3])
    checkInstalled(root, resolve(process.argv[3]));
  else if (command === "update") {
    checkPatches(root);
    const packages = updateablePackages(manifestAt(root));
    if (packages.length > 0) run([process.execPath, "update", "--latest", ...packages], root);
    checkPatches(root);
  } else
    throw new Error(
      "Usage: bun scripts/package-patches.ts check|verify|update|installed <directory>",
    );
}
