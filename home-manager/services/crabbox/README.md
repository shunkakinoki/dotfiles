# Crabbox on Kyber

Crabbox runs as two systemd user services on Kyber:

- `crabbox-postgres.service` runs PostgreSQL on loopback port `55432`.
- `crabbox.service` runs the upstream Node coordinator on host port `18080`; Kyber's
  WAN firewall blocks direct public access while the local Kubernetes host gateway
  remains reachable.

The coordinator installation is intentionally separate from the service definition. Run
`ulb crabbox` to clone/update Crabbox, install its locked npm dependencies, build
`worker/dist-node/server.mjs`, and generate the local coordinator wrapper consumed by
the service.

Home Manager creates and starts the services. The production Kubernetes ingress proxies
the host service at `https://crabbox.shunkakinoki.com`; Tailscale Serve retains the
tailnet-only `https://kyber.tail950b36.ts.net:10443` compatibility endpoint. PostgreSQL
is never exposed.

Generated database and auth secrets live in
`~/.config/crabbox/coordinator/generated.env` with mode `0600`. Optional provider and
coordinator settings belong in the machine-local `~/dotfiles/.env`; no provider token is
required merely to start the coordinator.

The coordinator trusts forwarded origin and client headers only from Kyber's Kubernetes
pod CIDR (`10.42.1.0/24` by default). Override `CRABBOX_TRUSTED_PROXY_CIDRS` in the
machine-local environment if the cluster pod CIDR changes.

Portal login requires a GitHub OAuth app with these URLs:

- Homepage: `https://crabbox.shunkakinoki.com`
- Callback: `https://crabbox.shunkakinoki.com/v1/auth/github/callback`

Put `CRABBOX_GITHUB_CLIENT_ID`, `CRABBOX_GITHUB_CLIENT_SECRET`, and
`CRABBOX_GITHUB_ALLOWED_ORGS` in `~/dotfiles/.env`. The OAuth secret must remain
machine-local and must not be committed.

Browser Code is disabled until `CRABBOX_CODE_ORIGIN_TEMPLATE` has matching wildcard DNS,
TLS, and WebSocket routing.

```bash
ulb crabbox
systemctl --user restart crabbox-postgres crabbox
systemctl --user status crabbox-postgres crabbox
curl --fail http://127.0.0.1:18080/v1/health
curl --fail http://127.0.0.1:18080/v1/ready
```
