# Managed server ownership

On Linux, an installed service owns the default T3 home. Use `t3` or
`t3 serve` to start it through systemd; use a separate `T3CODE_HOME` for a
deliberate foreground server. Foreground flags on the managed home are rejected
rather than silently ignored. Help and ordinary CLI queries remain available.

The unit's startup check and the periodic connect check inspect the serving
process recorded in `userdata/server-runtime.json`. Both its service cgroup and
launcher IPC context must be present. An active launcher alone is insufficient:
it can remain alive after another process wins the ownership lock, leaving the
client unable to update that server. Missing or stale runtime records are retried
for up to 30 seconds during startup; a live unmanaged owner fails immediately.

Checks never kill a conflicting owner or remove its ownership database. An
existing conflict needs a deliberate handoff after preserving active work.
Direct invocations of downloaded binaries or `npx t3 ...` bypass the managed CLI
wrapper; use the wrapper for routine starts. The service still detects such
conflicts instead of reporting a healthy launcher.

Deploy with the normal Home Manager activation and `make t3-service`. Verify
`systemctl --user status t3code.service` and the connect service's exit status.
Future updates remain owned by T3's launcher; these checks neither pin a release
nor perform scheduled restarts or upgrades.
