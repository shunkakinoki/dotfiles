# Beads issue tracking

Run `bd prime` for CLI guidance. Kyber SQL on port 3307 is the sole live
Beads authority for reads, writes, claims, and leases. Managed client settings
supply the runtime store identity; each agent execution uses a distinct actor.

```sh
bd ready
bd show <issue-id>
bd update <issue-id> --claim
bd close <issue-id>
bd --readonly show <issue-id>
```

Read each mutation back before reporting success. A timeout has an unknown
outcome: read the authority before retrying. Unavailable reads never mean an
empty queue. There is no offline writable fallback or push/pull publication.

Preserve old replica directories as recovery data. Activation requires an
ordered snapshot, reconciliation, cutover, verification, and rollback operation;
see the Beads section in the repository README. JSONL exports are not complete
backups of leases, journals, or database history.
