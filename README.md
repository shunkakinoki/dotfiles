# Dotfiles

## Installation

See [PREREQUISITES.md](./PREREQUISITES.md) for private credentials and managed CLI requirements.

```bash
 curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/main/install.sh | sh
```

To pin a named host (skips hostname auto-detection):

```bash
 curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/main/install.sh | HOST={NAMED_HOST_HERE} sh
```

For troubleshooting and frequently asked questions, see [FAQ.md](./FAQ.md).

For default and fallback model assignments per harness, see [MODELS.md](./MODELS.md).

For Kamino setup and verification, see the [host runbook](named-hosts/kamino/README.md).

## Credits

See [REFERENCES.md](./REFERENCES.md) for more information.

## Beads authority

Kyber owns the live Beads SQL service on port 3307. All fleet clients, including
future Kamino hosts, read and write that authority with local auto-start disabled.
Only Kyber runs the SQL service and Linear reconciliation. Writable replica
services, federation timers, the remotes mirror, database auto-provisioning, and
the obsolete public JSONL mirror are retired. Existing data is preserved.

Activation requires quiescing writers and publishers, full restorable snapshots
of every store including ignored leases and journals, and lossless reconciliation
of unpublished changes into Kyber. Activate the reviewed policy only after those
checks; restart clients with stale inherited environment and verify authoritative
reads on every machine through the existing fleet read monitor. Startup does not
move or import old databases. Keep recovery snapshots until restore and claim
checks pass. Rollback must preserve and reconcile new Kyber writes before changing
routing; returning to an old writable replica would lose current state.
