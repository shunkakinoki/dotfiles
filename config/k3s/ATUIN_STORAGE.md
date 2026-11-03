# Atuin storage on the data disk

The Kyber-only mount keeps `/home/ubuntu/.local/share/atuin` on the existing
data filesystem. It lives outside containerd's managed blob directories and
depends on that filesystem's mount. The Atuin daemon's drop-in refuses to
start when its data path is not mounted. Other hosts keep their current paths.

The source declares steady-state mount and service behavior only. The separate
`scripts/atuin-storage.ts` operation converts existing storage after explicit
operator approval. It never runs during normal activation or on a timer.

Run the operation on Kyber using the existing Bun executable, with administrator
authority for apply and verification:

```sh
bun scripts/atuin-storage.ts --dry-run
bun scripts/atuin-storage.ts --apply
bun scripts/atuin-storage.ts --verify
bun scripts/atuin-storage.ts --release-root-copy
```

Apply takes an exclusive kernel lock, stages online, stops only the Atuin
daemon and socket, refuses remaining open handles, then completes the final
copy. It checks file bytes, modes and ownership, copied SQLite integrity and
table counts, and an independent backup before mounting the destination.
Database contents and the opaque key are never printed. SQLite shared-memory
files are copied but excluded from byte comparison because database readers
reconstruct them; WAL files remain part of the preservation proof.

The original root-side copy remains until a separate verified release. That
phase checks the mounted application's health, nondecreasing record counts,
and the original against the retained pre-cutover backup before releasing the
duplicate. It never prunes database rows or removes the backup. Inspect the
printed rollback state after any refusal; do not overwrite existing migration
outputs or repeat apply blindly.

Before mount cutover, a failure restores the original path and named units.
After cutover, newer records may exist at the destination: keep that current
copy and the original intact and recover the named units in place. To move back,
quiesce the named units, copy the current data back with the same byte/database
verification, remove only this mount and drop-in, and restore the same units.
Never restore an older backup over newly captured records.

## Recovery before an independent backup

An operator can explicitly waive the independent backup and prioritize service
recovery after the quiescent final staging copy has completed. First stop the
previous operation through its authorized owner; never run concurrent migrations.
Keep the two Atuin units inactive and retain both storage copies. Then run:

```sh
bun scripts/atuin-storage.ts --recover-without-backup
bun scripts/atuin-storage.ts --release-root-copy
bun scripts/atuin-storage.ts --verify
```

This mode requires an existing staging directory, no previous receipt or cutover,
no backup, and no open source handles. It freshly compares every non-ephemeral
file's bytes, modes and owners and checks that copied databases and tables open.
It mounts that exact copy, restarts the named units, and records actual new-capture
proof. It does not repeat the copy or create a backup. A mismatched copy is refused.

Matching mount and drop-in declarations installed by activation are reused,
including managed symlinks. Different existing declarations are refused before
data verification. Rollback removes only declarations created by the operation;
it preserves preexisting matching files and their ownership.

The separate release checks the mount, application health, successful capture,
original directory identity and absence of original open handles before freeing
the old root duplicate. The retained data is then the mounted copy only. Full
SQLite integrity and count scans are explicitly pending until the final verify
finishes; readability is not a full integrity result. A later integrity failure
must be reported and handled in place without pruning records or claiming a backup.
Receipts are versioned; an older operation must be completed with its matching
revision rather than overwriting its receipt or guessing a continuation state.
