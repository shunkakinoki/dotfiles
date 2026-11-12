# Beads authority

The GKE Dolt server at `beads-dolt.tail950b36.ts.net` owns the live Beads SQL
service on port 3307. All fleet clients, including Kyber and future Kamino hosts,
read and write that authority with local auto-start disabled. Kyber's Dolt server
is its cluster-replication standby and takes writes only after an operator
failover with `dolt_assume_cluster_role`. Kyber runs the Linear reconciliation
against the GKE authority. Writable replica services, federation timers, the
remotes mirror, database auto-provisioning, and the obsolete public JSONL mirror
are retired. Existing data is preserved.

Activation requires quiescing writers and publishers, full restorable snapshots
of every store including ignored leases and journals, and lossless reconciliation
of unpublished changes into the authority. Activate the reviewed policy only after
those checks; restart clients with stale inherited environment and verify
authoritative reads on every machine through the existing fleet read monitor.
Startup does not move or import old databases. Keep recovery snapshots until
restore and claim checks pass. Rollback must preserve and reconcile new authority
writes before changing routing; returning to an old writable replica would lose
current state.
