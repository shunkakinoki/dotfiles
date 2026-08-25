# Crabbox on Kyber

Crabbox runs as two systemd user services on Kyber:

- `crabbox-postgres.service` runs PostgreSQL on loopback port `55432`.
- `crabbox.service` runs the upstream Node coordinator on loopback port `18080`.

The coordinator installation is intentionally separate from the service definition. Run
`ulb crabbox` to clone/update Crabbox, install its locked npm dependencies, build
`worker/dist-node/server.mjs`, and generate the local coordinator wrapper consumed by
the service.

Home Manager creates and starts the services. Tailscale Serve publishes the coordinator
at `https://kyber.tail950b36.ts.net:10443` without exposing PostgreSQL.

Generated database and auth secrets live in
`~/.config/crabbox/coordinator/generated.env` with mode `0600`. Optional provider and
coordinator settings belong in the machine-local `~/dotfiles/.env`; no provider token is
required merely to start the coordinator.

Browser Code is disabled until `CRABBOX_CODE_ORIGIN_TEMPLATE` has matching wildcard DNS,
TLS, and WebSocket routing.

```bash
ulb crabbox
systemctl --user restart crabbox-postgres crabbox
systemctl --user status crabbox-postgres crabbox
curl --fail http://127.0.0.1:18080/v1/health
curl --fail http://127.0.0.1:18080/v1/ready
```
