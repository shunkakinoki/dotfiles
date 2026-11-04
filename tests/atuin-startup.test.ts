import { afterEach, expect, test } from "bun:test";
import { Database } from "bun:sqlite";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const fixtures: string[] = [];
afterEach(() => {
  for (const path of fixtures.splice(0)) rmSync(path, { recursive: true });
});
function fixture() {
  const root = mkdtempSync(join(tmpdir(), "atuin-startup-"));
  fixtures.push(root);
  const bin = join(root, "bin");
  mkdirSync(bin);
  return { root, bin };
}
function executable(path: string, text: string) {
  const bash = Bun.which("bash");
  if (!bash) throw new Error("Bash required");
  writeFileSync(path, text.replace(/^#!\/usr\/bin\/env bash\n/, `#!${bash}\n`));
  chmodSync(path, 0o755);
}
function wrapper(bin: string, actual: string) {
  const timeout = Bun.which("timeout");
  if (!timeout) throw new Error("GNU timeout required");
  executable(
    join(bin, "atuin"),
    readFileSync(
      new URL("../home-manager/programs/atuin/hook-client.sh", import.meta.url),
      "utf8"
    )
      .replaceAll("@timeout@", timeout)
      .replaceAll("@atuin@", actual)
  );
}

test("actual generated fish preexec returns to the executor when the history client hangs", async () => {
  const { root, bin } = fixture();
  const atuin = process.env.ATUIN_TEST_BIN ?? Bun.which("atuin");
  if (!atuin) throw new Error("Atuin required");
  const generated = Bun.spawnSync([atuin, "init", "fish"]);
  expect(generated.exitCode).toBe(0);
  const init = join(root, "init.fish");
  writeFileSync(init, generated.stdout);
  const stub = join(root, "client");
  executable(
    stub,
    '#!/usr/bin/env bash\nif [ "$1 $2" = "history start" ]; then touch "$HOOK_MARKER"; trap "" TERM; exec sleep 60; fi\nexit 0\n'
  );
  wrapper(bin, stub);
  const started = Date.now();
  const child = Bun.spawn(
    [
      "fish",
      "--no-config",
      "-c",
      'set -e fish_private_mode; source "$ATUIN_INIT"; functions -q _atuin_preexec; or exit 98; emit fish_preexec "echo executor"; echo EXECUTOR_READY',
    ],
    {
      env: {
        ...process.env,
        PATH: `${bin}:${process.env.PATH}`,
        HOME: root,
        XDG_CONFIG_HOME: join(root, "config"),
        HOOK_MARKER: join(root, "called"),
        ATUIN_INIT: init,
        ATUIN_SESSION: "fixture",
        ATUIN_SHLVL: "1",
      },
      stdout: "pipe",
      stderr: "pipe",
    }
  );
  const output = await new Response(child.stdout).text();
  expect(await child.exited).toBe(0);
  expect(readFileSync(join(root, "called"), "utf8")).toBe("");
  expect(Date.now() - started).toBeGreaterThanOrEqual(1900);
  expect(output).toContain("EXECUTOR_READY");
  expect(Date.now() - started).toBeLessThan(4500);
}, 6000);

test("failed storage and unavailable daemon fail promptly without changing non-hook commands", () => {
  const { root, bin } = fixture();
  const stub = join(root, "client");
  executable(
    stub,
    '#!/usr/bin/env bash\nif [ "$1" = history ]; then echo "daemon unavailable or storage read-only" >&2; exit 1; fi\nprintf "%s\\n" "$*"\n'
  );
  wrapper(bin, stub);
  for (const action of ["start", "end"]) {
    const result = Bun.spawnSync(
      [join(bin, "atuin"), "history", action, "--", "fixture"],
      {
        env: { ...process.env, HOME: root },
      }
    );
    expect(result.exitCode).toBe(1);
    expect(result.stderr.toString()).toContain("storage read-only");
  }
  const result = Bun.spawnSync([join(bin, "atuin"), "sync", "--force"]);
  expect(result.exitCode).toBe(0);
  expect(result.stdout.toString().trim()).toBe("sync --force");
});

test("storage guard rejects missing, root-backed and wrong-directory mounts", () => {
  const { root, bin } = fixture();
  executable(
    join(bin, "findmnt"),
    '#!/usr/bin/env bash\n[ -n "${MOUNT_READING:-}" ] || exit 1\nprintf "%s\\n" "$MOUNT_READING"\n'
  );
  for (const reading of [
    "",
    "root-uuid /",
    "90f29a7b-38ff-460b-b534-92a02f1412ec /wrong",
    "90f29a7b-38ff-460b-b534-92a02f1412ec /host-state/atuin-ubuntu",
  ]) {
    const result = Bun.spawnSync(
      ["bash", "config/k3s/atuin-storage-guard.sh"],
      {
        env: {
          ...process.env,
          PATH: `${bin}:${process.env.PATH}`,
          HOME: root,
          MOUNT_READING: reading,
        },
      }
    );
    expect(result.exitCode === 0).toBe(
      reading.endsWith(" /host-state/atuin-ubuntu")
    );
  }
});

test("healthy real Atuin capture retains command text and exit status", () => {
  const { root, bin } = fixture();
  const atuin = process.env.ATUIN_TEST_BIN ?? Bun.which("atuin");
  if (!atuin) throw new Error("Atuin required");
  const config = join(root, "config");
  mkdirSync(config);
  writeFileSync(
    join(config, "config.toml"),
    `db_path = "${root}/history.db"\nauto_sync = false\n[daemon]\nenabled = false\n[sync]\nrecords = false\n`
  );
  wrapper(bin, atuin);
  const env = {
    ...process.env,
    HOME: root,
    ATUIN_CONFIG_DIR: config,
    XDG_DATA_HOME: join(root, "data"),
    XDG_CONFIG_HOME: config,
  };
  const start = Bun.spawnSync(
    [join(bin, "atuin"), "history", "start", "--", "echo preserved-history"],
    { env }
  );
  expect(start.exitCode).toBe(0);
  const id = start.stdout.toString().trim();
  expect(id.length).toBeGreaterThan(0);
  const end = Bun.spawnSync(
    [join(bin, "atuin"), "history", "end", "--exit", "7", "--", id],
    {
      env,
    }
  );
  expect(end.exitCode).toBe(0);
  const db = new Database(join(root, "history.db"), { readonly: true });
  try {
    expect(
      db.query("SELECT command, exit FROM history WHERE id = ?").get(id)
    ).toEqual({
      command: "echo preserved-history",
      exit: 7,
    });
  } finally {
    db.close();
  }
});

test("host health escalates the urgent root band independently of the earlier warning", () => {
  const { root } = fixture();
  const script =
    'source config/k3s/kyber-host-health.sh; set_alert() { echo "$1: $2"; }; clear_alert() { :; }; df() { case "$*" in *avail*) echo Avail; echo 84825604096;; *) echo Use%; echo 91%;; esac; }; check_node_filesystem';
  const result = Bun.spawnSync(["bash", "-c", script], {
    env: { ...process.env, KYBER_HOST_HEALTH_STATE_DIR: root },
  });
  expect(result.exitCode).toBe(0);
  expect(result.stdout.toString()).toContain("node-filesystem-urgent");
  expect(result.stdout.toString()).toContain("50 GiB kubelet emergency floor");
});

// Nix build sandboxes do not expose /proc's mount table. This live systemd
// condition check needs that table; the mocked storage-guard test runs everywhere.
test.skipIf(
  process.platform !== "linux" || !existsSync("/proc/self/mountinfo")
)(
  "systemd mount condition rejects an ordinary directory without starting services",
  () => {
    const { root } = fixture();
    const missing = Bun.spawnSync([
      "systemd-analyze",
      "condition",
      `ConditionPathIsMountPoint=${root}`,
    ]);
    expect(missing.exitCode).not.toBe(0);
    const mounted = Bun.spawnSync([
      "systemd-analyze",
      "condition",
      "ConditionPathIsMountPoint=/",
    ]);
    expect(mounted.exitCode).toBe(0);
  }
);
