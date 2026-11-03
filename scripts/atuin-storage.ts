#!/usr/bin/env bun
import { Database } from "bun:sqlite";
import {
  chmodSync,
  chownSync,
  closeSync,
  constants,
  copyFileSync,
  existsSync,
  lstatSync,
  mkdirSync,
  openSync,
  readdirSync,
  readFileSync,
  readSync,
  readlinkSync,
  renameSync,
  rmdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { hostname } from "node:os";
import { dirname, join, resolve } from "node:path";

const SOURCE = "/home/ubuntu/.local/share/atuin";
const DISK = "/var/lib/rancher/k3s/agent/containerd";
const UUID = "90f29a7b-38ff-460b-b534-92a02f1412ec";
const PARENT = `${DISK}/host-state`;
const DESTINATION = `${PARENT}/atuin-ubuntu`;
const BACKUP = `${PARENT}/atuin-ubuntu.before-migration`;
const ROOT_COPY = `${SOURCE}.before-storage-migration`;
const RECORD = `${PARENT}/atuin-storage-migration.json`;
const UNIT = "home-ubuntu-.local-share-atuin.mount";
const UNIT_TARGET = `/etc/systemd/system/${UNIT}`;
const DROPIN = "/home/ubuntu/.config/systemd/user/atuin-daemon.service.d/20-storage.conf";
const CONFIG = resolve(import.meta.dir, "../config/k3s");
const UNITS = ["atuin-daemon.socket", "atuin-daemon.service"];
const GIB = 1024 ** 3;

function requireThat(ok: unknown, message: string): asserts ok {
  if (!ok) throw new Error(message);
}

function run(argv: string[], quiet = false): string {
  const child = Bun.spawnSync(argv, { stdout: "pipe", stderr: "pipe" });
  requireThat(
    child.exitCode === 0,
    `${argv[0]} failed (exit ${child.exitCode}); no captured content is printed`,
  );
  return quiet ? "" : child.stdout.toString().trim();
}

function user(argv: string[], quiet = false): string {
  return run(
    [
      "/usr/sbin/runuser",
      "-u",
      "ubuntu",
      "--",
      "env",
      "HOME=/home/ubuntu",
      "XDG_RUNTIME_DIR=/run/user/1000",
      "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus",
      ...argv,
    ],
    quiet,
  );
}

function service(action: string): void {
  user(["systemctl", "--user", action, ...UNITS], true);
}

function phase(name: string): void {
  console.log(`${new Date().toISOString()} phase=${name}`);
}

function matchingDeclaration(source: string, target: string): boolean {
  if (!existsSync(target)) return false;
  requireThat(statSync(target).isFile(), "Existing declaration is not a regular file");
  requireThat(
    readFileSync(source).equals(readFileSync(target)),
    "Existing declaration differs; retain it and refuse cutover",
  );
  return true;
}

export function ensureDeclaration(
  source: string,
  target: string,
  uid: number,
  gid: number,
): boolean {
  // Activation can install these first. Preserve matching managed links rather
  // than attempting to write through them into the immutable store.
  if (matchingDeclaration(source, target)) return false;
  copyFileSync(source, target, constants.COPYFILE_EXCL);
  chmodSync(target, 0o644);
  chownSync(target, uid, gid);
  return true;
}

export type Entry = {
  path: string;
  mode: number;
  uid: number;
  gid: number;
  size: number;
  hash: string;
};

export function snapshot(root: string): Entry[] {
  const rows: Entry[] = [];
  function walk(relative: string): void {
    const path = join(root, relative);
    const s = lstatSync(path);
    requireThat(
      s.isDirectory() || s.isFile() || s.isSymbolicLink(),
      "Unexpected special file in storage; refuse to omit it",
    );
    // SQLite shared memory is reconstructed by read-only database connections.
    if (s.isFile() && relative.endsWith("-shm")) return;
    let hash = "directory";
    if (s.isSymbolicLink()) hash = `link:${readlinkSync(path)}`;
    if (s.isFile()) {
      const digest = new Bun.CryptoHasher("sha256");
      const fd = openSync(path, constants.O_RDONLY | constants.O_NOFOLLOW);
      try {
        const buffer = Buffer.allocUnsafe(4 * 1024 * 1024);
        let length: number;
        while ((length = readSync(fd, buffer, 0, buffer.length, null)) > 0)
          digest.update(buffer.subarray(0, length));
        hash = digest.digest("hex");
      } finally {
        closeSync(fd);
      }
    }
    rows.push({
      path: relative,
      mode: s.mode,
      uid: s.uid,
      gid: s.gid,
      size: s.isDirectory() ? 0 : s.size,
      hash,
    });
    if (s.isDirectory())
      for (const name of readdirSync(path).sort()) walk(relative ? `${relative}/${name}` : name);
  }
  walk("");
  return rows;
}

export function compareCopies(a: Entry[], b: Entry[]): void {
  requireThat(
    JSON.stringify(a) === JSON.stringify(b),
    "Storage copies differ; retain the original and refuse cutover/release",
  );
}

export function databaseCounts(
  root: string,
  scan: "full" | "readability" = "full",
): Record<string, Record<string, string>> {
  const result: Record<string, Record<string, string>> = {};
  for (const name of readdirSync(root)
    .filter((name) => name.endsWith(".db"))
    .sort()) {
    const path = join(root, name);
    const owner = lstatSync(path);
    requireThat(owner.isFile(), "A SQLite database is not a regular file");
    const sharedMemory = `${path}-shm`;
    const hadSharedMemory = existsSync(sharedMemory);
    const db = new Database(path, { readonly: true });
    try {
      if (scan === "full") {
        const integrity = db.query("PRAGMA quick_check").all() as Record<string, unknown>[];
        requireThat(
          integrity.length === 1 && Object.values(integrity[0]!)[0] === "ok",
          `SQLite integrity check failed for ${name}`,
        );
      }
      const tables = db
        .query(
          "SELECT name FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .all() as { name: string }[];
      result[name] = {};
      for (const table of tables) {
        const identifier = table.name.replaceAll('"', '""');
        if (scan === "readability") {
          db.query(`SELECT 1 FROM "${identifier}" LIMIT 1`).get();
          continue;
        }
        const row = db
          .query(`SELECT CAST(count(*) AS TEXT) AS count FROM "${identifier}"`)
          .get() as { count: string };
        result[name]![table.name] = row.count;
      }
    } finally {
      db.close();
      // A privileged read-only WAL connection can create shared memory. Keep
      // that newly created transient file writable by the database's owner.
      if (!hadSharedMemory && existsSync(sharedMemory) && process.getuid?.() === 0) {
        requireThat(lstatSync(sharedMemory).isFile(), "Unexpected SQLite shared-memory file type");
        chownSync(sharedMemory, owner.uid, owner.gid);
      }
    }
  }
  requireThat(
    ["history.db", "records.db", "threads.db"].every((name) => name in result),
    "A required Atuin database is missing",
  );
  return result;
}

function verifyDisk(): void {
  requireThat(hostname().split(".")[0] === "kyber", "This operation is restricted to Kyber");
  requireThat(
    run(["findmnt", "-n", "-o", "UUID", "-T", DISK]) === UUID,
    "Unexpected destination filesystem UUID",
  );
  requireThat(
    run(["findmnt", "-n", "-o", "TARGET", "-T", DISK]) === DISK,
    "Destination disk is not mounted at its declared path",
  );
}

function mounted(): boolean {
  return Bun.spawnSync(["mountpoint", "-q", SOURCE]).exitCode === 0;
}

function assertQuiescent(root = SOURCE): void {
  const p = Bun.spawnSync(["/home/ubuntu/.nix-profile/bin/lsof", "-t", "+D", root], {
    stdout: "pipe",
    stderr: "pipe",
  });
  requireThat(
    p.exitCode === 1 && p.stdout.length === 0 && p.stderr.length === 0,
    "Atuin storage has open handles or liveness could not be proved; no foreign process will be killed",
  );
}

function copy(source: string, target: string, staging = false): void {
  const p = Bun.spawnSync(
    [
      "rsync",
      "-aHAX",
      "--numeric-ids",
      "--delete",
      "--no-whole-file",
      "--info=progress2,name0",
      `${source}/`,
      `${target}/`,
    ],
    { stdout: "inherit", stderr: "pipe" },
  );
  // A live staging copy is not a consistency proof. Vanished files must be
  // resolved by the mandatory quiescent copy and byte/database checks.
  requireThat(
    p.exitCode === 0 || (staging && p.exitCode === 24),
    "Storage copy failed; captured filenames are not printed",
  );
}

type Migration = {
  version: 2;
  source: string;
  destination: string;
  backup: string;
  rootCopy: string;
  appliedAt: string;
  counts: Record<string, Record<string, string>> | null;
  backupRetained: boolean;
  originalDev: number;
  originalIno: number;
  captureVerified: boolean;
  released: boolean;
};

function readRecord(): Migration {
  const r = JSON.parse(readFileSync(RECORD, "utf8")) as Migration;
  requireThat(
    r.version === 2 &&
      r.source === SOURCE &&
      r.destination === DESTINATION &&
      r.backup === BACKUP &&
      r.rootCopy === ROOT_COPY &&
      typeof r.backupRetained === "boolean" &&
      typeof r.captureVerified === "boolean" &&
      Number.isSafeInteger(r.originalDev) &&
      Number.isSafeInteger(r.originalIno) &&
      (!r.backupRetained || r.counts !== null),
    "Migration record does not match the approved paths",
  );
  return r;
}

function record(r: Migration): void {
  writeFileSync(RECORD, `${JSON.stringify(r)}\n`, { mode: 0o600 });
  chmodSync(RECORD, 0o600);
}

function verifyApplication(): void {
  requireThat(mounted(), "Atuin source path is not a mount");
  requireThat(
    statSync(SOURCE).dev === statSync(DESTINATION).dev &&
      statSync(SOURCE).ino === statSync(DESTINATION).ino,
    "The application path is not bound to the verified destination",
  );
  for (const unit of UNITS)
    requireThat(
      user(["systemctl", "--user", "is-active", unit]) === "active",
      "A named Atuin unit is not active",
    );
  user(
    [
      "/home/ubuntu/.nix-profile/bin/atuin",
      "search",
      "--limit",
      "1",
      "--format",
      "{uuid}",
      "--filter-mode",
      "global",
    ],
    true,
  );
  console.log("mount=verified units=active existing-history=readable");
}

function verifyCapture(): void {
  const atuin = "/home/ubuntu/.nix-profile/bin/atuin";
  const command = ["findmnt", "-n", "-o", "UUID", "-T", SOURCE];
  const id = user([
    atuin,
    "history",
    "start",
    "--author",
    "codex",
    "--author-kind",
    "agent",
    "--",
    command.join(" "),
  ]);
  requireThat(/^[0-9a-f-]+$/i.test(id), "Atuin did not return a capture identifier");
  requireThat(
    user(command) === UUID,
    "The actual capture-verification command resolved the wrong disk",
  );
  user([atuin, "history", "end", "--exit", "0", id], true);
  const db = new Database(join(SOURCE, "history.db"), { readonly: true });
  try {
    requireThat(
      db.query("SELECT 1 FROM history WHERE id=? AND exit=0").get(id) !== null,
      "The real verification command was not captured",
    );
  } finally {
    db.close();
  }
  console.log("new-capture=verified");
}

function dryRun(recoverWithoutBackup = false): void {
  verifyDisk();
  const size = Number(run(["du", "-sk", SOURCE]).split(/\s/)[0]) * 1024;
  const available = Number(run(["df", "-B1", "--output=avail", DISK]).split(/\s+/).at(-1));
  const source = statSync(SOURCE);
  requireThat(source.uid === 1000 && source.gid === 1000, "Unexpected source owner");
  requireThat(
    available > (recoverWithoutBackup ? 0 : size * 2) + 50 * GIB,
    "Insufficient space for this operation and the destination reserve",
  );
  console.log(
    JSON.stringify({
      phase: "dry-run",
      host: "kyber",
      allocatedBytes: size,
      destinationAvailableBytes: available,
      estimatedRootBytesFreed: size,
      alreadyMounted: mounted(),
      stops: UNITS,
      uuid: UUID,
    }),
  );
}

function apply(recoverWithoutBackup = false): void {
  dryRun(recoverWithoutBackup);
  for (const unit of UNITS)
    requireThat(
      user(["systemctl", "--user", "show", unit, "--property=ActiveState", "--value"]) ===
        (recoverWithoutBackup ? "inactive" : "active"),
      "A named unit changed state since the approved preflight",
    );
  requireThat(!mounted(), "Already mounted; use --verify instead");
  for (const path of [BACKUP, ROOT_COPY, RECORD])
    requireThat(
      !existsSync(path),
      "Migration output already exists; inspect it instead of overwriting",
    );
  matchingDeclaration(join(CONFIG, UNIT), UNIT_TARGET);
  matchingDeclaration(join(CONFIG, "atuin-storage.conf"), DROPIN);
  requireThat(lstatSync(SOURCE).isDirectory(), "Source is not a real directory");
  requireThat(
    recoverWithoutBackup === existsSync(DESTINATION),
    "Recovery requires the completed staging copy; ordinary apply requires a fresh destination",
  );
  mkdirSync(PARENT, { recursive: true, mode: 0o700 });
  requireThat(
    lstatSync(PARENT).isDirectory() &&
      statSync(PARENT).uid === 0 &&
      (statSync(PARENT).mode & 0o077) === 0,
    "Destination parent owner or permissions differ",
  );
  if (!recoverWithoutBackup) mkdirSync(DESTINATION, { mode: 0o700 });
  else requireThat(lstatSync(DESTINATION).isDirectory(), "Staging is not a real directory");
  let stopped = recoverWithoutBackup;
  let cutover = false;
  let mountInstalled = false;
  let dropinInstalled = false;
  try {
    if (!recoverWithoutBackup) {
      phase("online-staging");
      copy(SOURCE, DESTINATION, true);
      phase("quiescent-final-copy");
      stopped = true;
      service("stop");
      assertQuiescent();
      copy(SOURCE, DESTINATION);
    }
    assertQuiescent();
    phase("verify-source-copy");
    const original = snapshot(SOURCE);
    compareCopies(original, snapshot(DESTINATION));
    let counts: Migration["counts"] = null;
    if (recoverWithoutBackup) {
      phase("database-readability-full-scan-deferred");
      databaseCounts(DESTINATION, "readability");
    } else {
      counts = databaseCounts(SOURCE);
      requireThat(
        JSON.stringify(counts) === JSON.stringify(databaseCounts(DESTINATION)),
        "Copied SQLite record counts differ",
      );
      compareCopies(snapshot(SOURCE), snapshot(DESTINATION));
      phase("independent-backup");
      mkdirSync(BACKUP, { mode: 0o700 });
      copy(DESTINATION, BACKUP);
      compareCopies(snapshot(SOURCE), snapshot(BACKUP));
      requireThat(
        JSON.stringify(counts) === JSON.stringify(databaseCounts(BACKUP)),
        "Backup SQLite counts differ",
      );
    }
    run(["sync", "-f", DISK], true);
    assertQuiescent();
    phase("mount-cutover");
    if (!existsSync(dirname(DROPIN))) {
      mkdirSync(dirname(DROPIN), { recursive: true, mode: 0o755 });
      chownSync(dirname(DROPIN), 1000, 1000);
    }
    dropinInstalled = ensureDeclaration(join(CONFIG, "atuin-storage.conf"), DROPIN, 1000, 1000);
    mountInstalled = ensureDeclaration(join(CONFIG, UNIT), UNIT_TARGET, 0, 0);
    renameSync(SOURCE, ROOT_COPY);
    mkdirSync(SOURCE, { mode: 0o700 });
    chownSync(SOURCE, 1000, 1000);
    run(["systemctl", "daemon-reload"], true);
    run(["systemctl", "enable", "--now", UNIT], true);
    cutover = true;
    record({
      version: 2,
      source: SOURCE,
      destination: DESTINATION,
      backup: BACKUP,
      rootCopy: ROOT_COPY,
      appliedAt: new Date().toISOString(),
      counts,
      backupRetained: !recoverWithoutBackup,
      originalDev: statSync(ROOT_COPY).dev,
      originalIno: statSync(ROOT_COPY).ino,
      captureVerified: false,
      released: false,
    });
    user(["systemctl", "--user", "daemon-reload"], true);
    service("start");
    stopped = false;
    verifyApplication();
    verifyCapture();
    record({ ...readRecord(), captureVerified: true });
    console.log(
      recoverWithoutBackup
        ? "cutover=verified original-root-copy=retained; run --release-root-copy, then --verify"
        : "cutover=verified original-root-copy=retained; run --verify, then --release-root-copy",
    );
    if (recoverWithoutBackup)
      console.log("backup=waived release-root-copy-before-full-verify=true full-integrity=pending");
  } catch (error) {
    phase("rollback");
    if (cutover || mounted()) {
      // New records may exist on the mounted copy. Keep it live for recovery;
      // never overwrite it with the pre-cutover snapshot.
      console.log("rollback=manual-required current-data=preserved original-root-copy=retained");
    } else {
      if (existsSync(ROOT_COPY)) {
        if (existsSync(SOURCE)) rmdirSync(SOURCE);
        renameSync(ROOT_COPY, SOURCE);
      }
      if (mountInstalled || dropinInstalled) {
        if (mountInstalled) {
          run(["systemctl", "disable", UNIT], true);
          rmSync(UNIT_TARGET);
        }
        if (dropinInstalled) rmSync(DROPIN);
        run(["systemctl", "daemon-reload"], true);
        user(["systemctl", "--user", "daemon-reload"], true);
      }
      if (stopped) service("start");
      console.log("rollback=original-restored staging-and-backup=retained");
    }
    throw error;
  }
}

function verify(): void {
  verifyDisk();
  const r = readRecord();
  verifyApplication();
  const current = databaseCounts(SOURCE);
  for (const [file, tables] of Object.entries(r.counts ?? {}))
    for (const [table, count] of Object.entries(tables)) {
      requireThat(
        BigInt(current[file]?.[table] ?? "-1") >= BigInt(count),
        "A SQLite record count fell below the verified baseline",
      );
    }
  if (!r.captureVerified) verifyCapture();
  if (r.counts === null || !r.captureVerified)
    record({ ...r, counts: r.counts ?? current, captureVerified: true });
  console.log(`sqlite-integrity=ok backup=${r.backupRetained ? "retained" : "waived"}`);
}

function release(): void {
  verifyDisk();
  let r = readRecord();
  if (r.backupRetained) {
    verify();
    r = readRecord();
  } else verifyApplication();
  requireThat(
    readRecord().captureVerified,
    "New capture has not been verified; retain the original",
  );
  requireThat(!r.released, "Root duplicate already released");
  requireThat(
    statSync(ROOT_COPY).dev !== statSync(DESTINATION).dev,
    "The duplicate is not on the old root filesystem",
  );
  requireThat(
    statSync(ROOT_COPY).dev === r.originalDev && statSync(ROOT_COPY).ino === r.originalIno,
    "The original root directory identity changed",
  );
  if (r.backupRetained) {
    compareCopies(snapshot(ROOT_COPY), snapshot(BACKUP));
    requireThat(
      JSON.stringify(databaseCounts(BACKUP)) === JSON.stringify(r.counts),
      "Backup differs from the pre-cutover record counts",
    );
  } else assertQuiescent(ROOT_COPY);
  run(["sync", "-f", DISK], true);
  phase("release-verified-root-duplicate");
  rmSync(ROOT_COPY, { recursive: true });
  record({ ...r, released: true });
  console.log(
    `released-root-duplicate=true backup=${r.backupRetained ? "retained" : "waived"} applied-at=${r.appliedAt}`,
  );
  console.log(run(["df", "-Pk", "/", DISK]));
}

if (import.meta.main) {
  try {
    const mode = process.argv[2] ?? "--dry-run";
    requireThat(
      process.argv.length <= 3 &&
        [
          "--dry-run",
          "--apply",
          "--recover-without-backup",
          "--verify",
          "--release-root-copy",
        ].includes(mode),
      "Choose --dry-run, --apply, --recover-without-backup, --verify or --release-root-copy",
    );
    if (mode !== "--dry-run") {
      requireThat(
        process.getuid?.() === 0,
        "Mutation and complete verification require the approved root execution route",
      );
      if (process.env.ATUIN_STORAGE_LOCKED !== "1") {
        const child = Bun.spawnSync(
          [
            "flock",
            "--nonblock",
            "/run/lock/atuin-storage-migration.lock",
            process.execPath,
            import.meta.path,
            mode,
          ],
          {
            env: { ...process.env, ATUIN_STORAGE_LOCKED: "1" },
            stdout: "inherit",
            stderr: "inherit",
          },
        );
        process.exit(child.exitCode);
      }
    }
    if (mode === "--dry-run") dryRun();
    else if (mode === "--apply") apply();
    else if (mode === "--recover-without-backup") apply(true);
    else if (mode === "--verify") verify();
    else release();
  } catch (error) {
    console.error(error instanceof Error ? error.message : "Storage migration refused");
    process.exitCode = 1;
  }
}
