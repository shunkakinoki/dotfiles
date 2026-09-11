# Upgrade guide

This guide covers upgrades that change the Beads client or its Dolt schema.
Routine Home Manager activation must not perform an implicit database migration.

## Before the upgrade

1. Announce a maintenance window and quiesce Beads writers, Linear sync, and
   orchestration clients.
2. Confirm the authoritative Dolt service is the only writable server and that
   clients route to it with `BEADS_NODE_ID=kyber`.
3. Capture a restorable snapshot of the database and record its identity,
   current revision, schema version, and timestamp.
4. Build the candidate Home Manager generation and run its Nix checks without
   switching any host.

## Apply the upgrade

Run the migration as an explicit, serialized operation owned by the Beads
maintainer:

```text
snapshot -> migrate -> commit Dolt working set -> verify schema -> resume clients
```

Do not run `bd` from an unrelated checkout with its own `.beads` prefix. Use the
canonical repository checkout so the intended database name and authority are
selected. Never point clients at a local replica to work around a failed
migration.

## Verify before resuming

The upgrade is successful only when all of these pass:

- the Dolt user service is active and its configured database is reachable;
- `bd doctor` completes without schema or transaction errors;
- a temporary Beads record can be created, read back, and closed;
- Linear sync reports either a clean result or an explicitly owned hold;
- orchestration clients can read the same authority through the fleet monitor.

Keep the previous Home Manager generation and database snapshot until these
checks pass on every client. A listening SQL port alone is not readiness.

## Failure and rollback

If migration or verification fails, stop dependent clients, preserve the dirty
working set and logs, and do not retry blindly. Roll back the Home Manager
generation only after reconciling any writes made after the snapshot. Restore a
database snapshot only through the Beads maintainer's documented recovery
operation; never delete a store or start a second writable server.

Record the exact client version, migration result, database revision, and
verification commands with the upgrade change.
