# Beskar Host Configuration

Beskar uses a root-owned standalone Home Manager profile at `/root`. Its fleet
checkout, Bun, Herdr state and per-host credentials belong to that account.
It does not own Kyber's k3s cluster or exit-node configuration.

## Bootstrap

Run the named configuration as root with the hostname `beskar`. Build and
inspect the generation before activating it:

```bash
git clone https://github.com/shunkakinoki/dotfiles /root/dotfiles
cd /root/dotfiles
make build HOST=beskar
make switch HOST=beskar
```

The one-line installer also supports a root SSH session on a fresh Ubuntu image:

```bash
curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/main/install.sh | HOST=beskar sh
```

The installer refuses an unprivileged account before checkout or activation.
It does not create an Ubuntu account or grant it administrative access. The
activation checks machine and Tailscale identity before the write boundary;
the updater uses that same guard before checkout or service actions and
declares `HOST=beskar` explicitly.

The profile uses ordinary OpenSSH over the tailnet, with the declared host key
and fleet peer authorization. Tailscale SSH is disabled; `tailscale ssh` needs
a separately enabled server and advertised host keys.

An existing Ubuntu-owned runtime needs an operator-approved preservation
handoff before switching. Keep active sessions, worktrees, custody and history
intact. Do not start a parallel root runtime, copy private keys or rotate
credentials as a bootstrap shortcut. After the reviewed handoff, verify root's
authenticated fleet access and an approved real provider probe.

## GitHub access

GitHub's OAuth device flow allows ten tokens per user and app, so Beskar
authenticates `gh` with its own fine-grained personal access token. The token
lives in Doppler `dotfiles/prd` as `GH_PAT_BESKAR`. Pipe it into `gh` from a
machine with Doppler access so the value never reaches shell history or an
argument list:

```bash
doppler --silent secrets get GH_PAT_BESKAR --project dotfiles --config prd --plain \
  | ssh beskar gh auth login --with-token
ssh beskar gh auth status
```

Home Manager already configures `gh` as the HTTPS git credential helper.
