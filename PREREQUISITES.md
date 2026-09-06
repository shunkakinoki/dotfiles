# Prerequisites

## CLIProxy credentials

Set `CLIPROXY_API_KEY` in `~/dotfiles/.env` on every host that uses CLIProxy.
This private, Git-ignored file is the credential source for the managed shell
environment. Keep it readable only by its owner:

```sh
chmod 600 ~/dotfiles/.env
```

Provision the key through a private channel; never commit it, paste it into a
command argument, or print the environment. Open a new shell after updating the
file so `coxec`, `coxech`, and the named Codex profiles receive the key. A service
or agent that is already running retains its previous environment until its
owner restarts it.

## Managed Codex installation

The CLI version and its platform binary must match the version declared in
`package.json`. The managed activation installs both. Check `codex --version`
from the same shell that launches `coxec`; an older binary earlier on `PATH`
can reject the current configuration before contacting the provider.

See [MODELS.md](./MODELS.md) for the CLIProxy profiles and their model assignments.

## App-server ownership

The Kyber refresh target restarts an installed standalone Codex daemon. When no
standalone installation exists, it preserves the app server owned by another
application. Update or restart that server through its owning application.
