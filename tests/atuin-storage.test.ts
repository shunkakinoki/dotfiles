import { afterEach, expect, test } from "bun:test";
import { Database } from "bun:sqlite";
import { chmodSync, cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { compareCopies, databaseCounts, snapshot } from "../scripts/atuin-storage";

const roots: string[] = [];
function fixture(): string {
  const root = mkdtempSync(join(tmpdir(), "atuin-storage-test-"));
  roots.push(root);
  for (const name of ["history.db", "records.db", "threads.db"]) {
    const db = new Database(join(root, name));
    db.run("CREATE TABLE entries(id TEXT PRIMARY KEY, value BLOB)");
    db.run("INSERT INTO entries VALUES (?, ?)", ["id", new Uint8Array([1, 2, 3])]);
    db.close();
  }
  writeFileSync(join(root, "key"), "fixture-only-opaque-key", { mode: 0o600 });
  return root;
}
afterEach(() => {
  for (const root of roots.splice(0)) rmSync(root, { recursive: true });
});

test("verifies all bytes, opaque key permissions and SQLite record counts", () => {
  const source = fixture();
  const copy = mkdtempSync(join(tmpdir(), "atuin-storage-copy-"));
  roots.push(copy);
  cpSync(source, copy, { recursive: true, preserveTimestamps: true });
  compareCopies(snapshot(source), snapshot(copy));
  expect(databaseCounts(copy)).toEqual(databaseCounts(source));
  expect(databaseCounts(copy)["records.db"]).toEqual({ entries: "1" });
});

test("refuses changed data or broader key permissions", () => {
  const source = fixture();
  const original = snapshot(source);
  chmodSync(join(source, "key"), 0o644);
  expect(() => compareCopies(original, snapshot(source))).toThrow("copies differ");
  chmodSync(join(source, "key"), 0o600);
  writeFileSync(join(source, "key"), "different-opaque-key");
  expect(() => compareCopies(original, snapshot(source))).toThrow("copies differ");
});

test("rejects corruption and a missing required database", () => {
  const root = fixture();
  writeFileSync(join(root, "threads.db"), "not a database");
  expect(() => databaseCounts(root)).toThrow();
  rmSync(join(root, "threads.db"));
  expect(() => databaseCounts(root)).toThrow("required Atuin database");
});

test("preserves WAL data while excluding reconstructed shared memory from byte comparison", () => {
  const root = fixture();
  const db = new Database(join(root, "history.db"));
  db.run("PRAGMA journal_mode=WAL");
  db.run("INSERT INTO entries VALUES (?, ?)", ["second", new Uint8Array([4])]);
  expect(databaseCounts(root)["history.db"]!.entries).toBe("2");
  const before = snapshot(root);
  expect(before.some((row) => row.path === "history.db-wal")).toBe(true);
  expect(before.some((row) => row.path.endsWith("-shm"))).toBe(false);
  db.close();
});

test("recovery readability preserves bytes and still refuses an unreadable database", () => {
  const root = fixture();
  const before = snapshot(root);
  databaseCounts(root, "readability");
  compareCopies(before, snapshot(root));
  writeFileSync(join(root, "threads.db"), "not a database");
  expect(() => databaseCounts(root, "readability")).toThrow();
});

test("a readable database still needs the deferred full integrity check", () => {
  const root = fixture();
  const path = join(root, "threads.db");
  const bytes = readFileSync(path);
  // A bad freelist pointer leaves ordinary table reads intact, but the full
  // SQLite checker must inspect and reject the corrupt allocation metadata.
  bytes.writeUInt32BE(0x7fffffff, 32);
  bytes.writeUInt32BE(1, 36);
  writeFileSync(path, bytes);
  databaseCounts(root, "readability");
  expect(() => databaseCounts(root)).toThrow("integrity check failed");
});
