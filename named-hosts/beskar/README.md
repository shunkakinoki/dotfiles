# Beskar Host Configuration

Beskar is a dedicated Ubuntu server for interactive T3 Code sessions. It uses
the same standalone Home Manager setup as Kyber, without Kyber's k3s cluster,
Beads authority, or Tailscale exit node.

## Bootstrap

Create the `ubuntu` user, set the hostname to `beskar`, install Tailscale and
Nix, then apply the named Home Manager configuration as `ubuntu`:

```bash
sudo hostnamectl set-hostname beskar
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable --now tailscaled
sudo tailscale up --accept-dns=true --ssh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux
git clone https://github.com/shunkakinoki/dotfiles ~/dotfiles
cd ~/dotfiles
make switch HOST=beskar
```

The one-line installer also supports a root SSH session when the `ubuntu`
account already exists with a home directory and administrative access:

```bash
curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/main/install.sh | HOST=beskar sh
```

It installs system prerequisites as root, then fetches `~/dotfiles` and runs
`make install` (including build and activation) as `ubuntu`. On a machine already
named `beskar`, `HOST=beskar` can be omitted. A previous checkout in `/root` is
left in place; installation uses the Ubuntu account's home directory.

## GitHub access

GitHub's OAuth device flow allows ten tokens per user and app, so Beskar
authenticates `gh` with its own fine-grained personal access token. The token
lives in Doppler `dotfiles/prd` as `GH_PAT_BESKAR`. Pipe it into `gh` from a
machine with Doppler access so the value never reaches shell history or an
argument list:

```bash
doppler secrets get GH_PAT_BESKAR --project dotfiles --config prd --plain \
  | ssh beskar gh auth login --with-token
ssh beskar gh auth status
```

Home Manager already configures `gh` as the HTTPS git credential helper.
