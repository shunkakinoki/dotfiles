import { afterEach, expect, test } from "bun:test";
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import {
  checkInstalled,
  checkPatches,
  patchedPackages,
  updateablePackages,
} from "../scripts/package-patches";

const roots: string[] = [];
afterEach(() => {
  for (const root of roots.splice(0))
    rmSync(root, { recursive: true, force: true });
});

const patch =
  "diff --git a/index.js b/index.js\n--- a/index.js\n+++ b/index.js\n@@ -1 +1 @@\n-export const limit = 512;\n+export const limit = 4096;\n";
function fixture() {
  const root = mkdtempSync(join(tmpdir(), "patch-policy-test-"));
  roots.push(root);
  const manifest = {
    dependencies: { tool: "1.0.0" },
    patchedDependencies: { "tool@1.0.0": "tool.patch" },
  };
  writeFileSync(join(root, "package.json"), JSON.stringify(manifest));
  writeFileSync(join(root, "tool.patch"), patch);
  writeFileSync(
    join(root, "bun.lock"),
    JSON.stringify({
      patchedDependencies: manifest.patchedDependencies,
      packages: { tool: ["tool@1.0.0"] },
    })
  );
  return { root, manifest };
}

test("rejects a version bump with a stale patch key", () => {
  const { root, manifest } = fixture();
  manifest.dependencies.tool = "1.0.1";
  writeFileSync(join(root, "package.json"), JSON.stringify(manifest));
  expect(() => checkPatches(root)).toThrow("must be pinned");
});

test("rejects missing patches, stale lock declarations and different resolutions", () => {
  const { root } = fixture();
  rmSync(join(root, "tool.patch"));
  expect(() => checkPatches(root)).toThrow("Missing patch");
  writeFileSync(join(root, "tool.patch"), patch);
  writeFileSync(
    join(root, "bun.lock"),
    JSON.stringify({ patchedDependencies: {} })
  );
  expect(() => checkPatches(root)).toThrow("declarations differ");
  writeFileSync(
    join(root, "bun.lock"),
    JSON.stringify({
      patchedDependencies: { "tool@1.0.0": "tool.patch" },
      packages: { tool: ["tool@1.0.1"] },
    })
  );
  expect(() => checkPatches(root)).toThrow("does not resolve");
});

test("proves installed postimages and rejects silently unpatched code", () => {
  const { root } = fixture();
  const installed = join(root, "node_modules/tool");
  mkdirSync(installed, { recursive: true });
  writeFileSync(
    join(installed, "package.json"),
    JSON.stringify({ version: "1.0.0" })
  );
  writeFileSync(join(installed, "index.js"), "export const limit = 4096;\n");
  expect(() => checkInstalled(root, root)).not.toThrow();
  writeFileSync(join(installed, "index.js"), "export const limit = 512;\n");
  expect(() => checkInstalled(root, root)).toThrow("failed");
});

test("the updater excludes scoped and unscoped patches", () => {
  expect(
    updateablePackages({
      dependencies: { "@scope/tool": "1.0.0", tool: "1.0.0", other: "^1.0.0" },
      patchedDependencies: {
        "@scope/tool@1.0.0": "scoped.patch",
        "tool@1.0.0": "tool.patch",
      },
    })
  ).toEqual(["other"]);
});

test("accepts exact optional patch pins and rejects conflicting pins", () => {
  const { root, manifest } = fixture();
  writeFileSync(
    join(root, "package.json"),
    JSON.stringify({
      optionalDependencies: manifest.dependencies,
      patchedDependencies: manifest.patchedDependencies,
    })
  );
  expect(() => checkPatches(root)).not.toThrow();
  writeFileSync(
    join(root, "package.json"),
    JSON.stringify({ ...manifest, optionalDependencies: { tool: "1.0.1" } })
  );
  expect(() => checkPatches(root)).toThrow("must be pinned");
});

test("the global missing-package loop leaves patched packages to the patch install", () => {
  const { root, manifest } = fixture();
  writeFileSync(
    join(root, "package.json"),
    JSON.stringify({
      ...manifest,
      dependencies: { ...manifest.dependencies, other: "1.0.0" },
    })
  );
  const script = readFileSync(
    resolve(
      import.meta.dir,
      "../home-manager/modules/npm-globals/install-npm-globals.sh"
    ),
    "utf8"
  );
  const loop = script.slice(
    script.indexOf("# Build list of packages"),
    script.indexOf("# Install missing packages one by one")
  );
  const result = Bun.spawnSync(
    ["bash", "-c", `${loop}\nprintf '%s\\n' "\u0024{MISSING[@]}"`],
    {
      env: {
        ...process.env,
        HOME: root,
        PACKAGE_JSON: join(root, "package.json"),
      },
      stdout: "pipe",
      stderr: "pipe",
    }
  );
  expect(result.exitCode).toBe(0);
  expect(result.stdout.toString().trim()).toBe("other");
});

test("managed activation and the service provide Git for postimage checks", () => {
  const config = readFileSync(
    resolve(import.meta.dir, "../home-manager/modules/npm-globals/default.nix"),
    "utf8"
  );
  expect(config.match(/^    export PATH=.*$/m)?.[0]).toContain(
    "${pkgs.git}/bin"
  );
  expect(config.match(/"PATH=.*"/)?.[0]).toContain("${pkgs.git}/bin");
});

test("managed activation and the service provide tar and gzip for postinstall unpacks", () => {
  const config = readFileSync(
    resolve(import.meta.dir, "../home-manager/modules/npm-globals/default.nix"),
    "utf8"
  );
  for (const path of [
    config.match(/^    export PATH=.*$/m)?.[0],
    config.match(/"PATH=.*"/)?.[0],
  ]) {
    expect(path).toContain("${pkgs.gnutar}/bin");
    expect(path).toContain("${pkgs.gzip}/bin");
  }
});

test("Renovate explicitly excludes every patched package", () => {
  const root = resolve(import.meta.dir, "..");
  const manifest = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
  const renovate = JSON.parse(
    readFileSync(join(root, "renovate.json"), "utf8")
  );
  for (const { name } of patchedPackages(manifest)) {
    expect(
      renovate.packageRules.some(
        (rule: { enabled?: boolean; matchPackageNames?: string[] }) =>
          rule.enabled === false && rule.matchPackageNames?.includes(name)
      )
    ).toBe(true);
  }
  expect(() => checkPatches(root)).not.toThrow();
});
