# Crabbox coordinator

Kyber runs the upstream Crabbox Node/PostgreSQL coordinator as a Home Manager
user service. The coordinator binds only to `127.0.0.1:8080`; Tailscale Serve
publishes it to the tailnet at `https://kyber.tail950b36.ts.net:10443`.

The first start creates `~/.config/crabbox/coordinator/generated.env` with mode
`0600`. It contains the local PostgreSQL password and randomly generated shared,
admin, and session tokens. Do not copy it into this repository.

Add provider credentials or override coordinator settings in the untracked
`~/dotfiles/.env`. For example:

```dotenv
HETZNER_TOKEN=replace-me
CRABBOX_SHARED_OWNER=you@example.com
CRABBOX_DEFAULT_ORG=example-org
```

Then restart and verify:

```bash
make systemctl-crabbox
systemctl --user status crabbox.service
curl --fail http://127.0.0.1:8080/v1/health
curl --fail http://127.0.0.1:8080/v1/ready
```

Configure a client without exposing the token in process arguments:

```bash
ssh kyber 'sed -n "s/^CRABBOX_SHARED_TOKEN=//p" ~/.config/crabbox/coordinator/generated.env' |
  crabbox login --url https://kyber.tail950b36.ts.net:10443 --token-stdin
```

Browser Code needs wildcard DNS, TLS, and WebSocket routing plus a matching
`CRABBOX_CODE_ORIGIN_TEMPLATE`; it is intentionally not enabled by the
tailnet-only single-host setup.
