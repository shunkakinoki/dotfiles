import { afterEach, expect, test } from "bun:test";
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const roots: string[] = [];
afterEach(() => {
  for (const root of roots.splice(0))
    rmSync(root, { recursive: true, force: true });
});

// The upstream bundle launcher, before its runtime calls process.title = "pi".
const upstream = `#!/usr/bin/env node
import { createRequire, enableCompileCache } from "node:module";

enableCompileCache();
createRequire(import.meta.url)("./cli-runtime.js");
`;

test.skipIf(process.platform !== "linux")(
  "Pi retains kernel argv after its runtime renames the process",
  () => {
    const node = Bun.which("node");
    expect(node).not.toBeNull();
    const root = mkdtempSync(join(tmpdir(), "pi-native-argv-"));
    roots.push(root);
    const bundle = join(root, "dist/bundle");
    mkdirSync(bundle, { recursive: true });
    writeFileSync(join(root, "package.json"), '{"type":"module"}');
    writeFileSync(join(bundle, "cli.js"), upstream);
    writeFileSync(
      join(bundle, "cli-runtime.js"),
      `
    import { readFileSync } from "node:fs";
    process.title = "pi";
    process.title = "pi busy";
    console.log(JSON.stringify({
      title: process.title,
      name: readFileSync("/proc/self/comm", "utf8").trim(),
      argv: readFileSync("/proc/self/cmdline", "utf8").split("\\0").filter(Boolean),
    }));
  `
    );
    const args = [
      join(bundle, "cli.js"),
      "--model",
      "provider/model",
      "--session",
      "/tmp/session with spaces.jsonl",
      "--no-extensions",
    ];
    const observe = () => {
      const result = Bun.spawnSync([node!, ...args], {
        stdout: "pipe",
        stderr: "pipe",
      });
      expect(result.exitCode).toBe(0);
      return JSON.parse(result.stdout.toString());
    };
    expect(observe().argv).not.toEqual([node, ...args]);
    const patch = resolve(
      import.meta.dir,
      "../patches/pi-coding-agent@1.5.2.patch"
    );
    const apply = Bun.spawnSync(
      ["git", "apply", "--unsafe-paths", "--directory", root, patch],
      { stdout: "pipe", stderr: "pipe" }
    );
    expect(apply.stderr.toString()).toBe("");
    expect(apply.exitCode).toBe(0);
    expect(observe()).toEqual({
      title: "pi busy",
      name: "pi busy",
      argv: [node, ...args],
    });
    expect(readFileSync(join(bundle, "cli.js"), "utf8")).toContain(
      'process.platform === "linux"'
    );
  }
);
