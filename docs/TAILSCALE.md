# Tailscale

Tailscale VPN connects all machines via WireGuard tunnels with MagicDNS.

## Machines

| Machine | OS | Method | Config location |
|---|---|---|---|
| galactica | macOS (aarch64-darwin) | Homebrew cask `tailscale-app` | `nix-darwin/config/homebrew.nix` |
| matic | NixOS (x86_64-linux) | `services.tailscale.enable` | `named-hosts/matic/default.nix` |
| kyber | Ubuntu (x86_64-linux) | Home-manager module `modules.tailscale` | `named-hosts/kyber/default.nix` |

## galactica (macOS)

Installed as a Homebrew cask (`tailscale-app`). The CLI is also available via `home-manager/packages/default.nix` (`tailscale`).

Managed through the macOS menu bar app. No nix service configuration.

### Setup

1. `make switch-galactica` installs the app
2. Open Tailscale from Applications and sign in

## matic (NixOS)

Uses the native NixOS Tailscale module:

```nix
# named-hosts/matic/default.nix
services.tailscale.enable = true;
```

This creates and enables the `tailscaled` systemd service automatically.

### Setup

1. `make build HOST=matic && make switch HOST=matic`
2. Authenticate:

```sh
sudo tailscale login
```

3. Verify:

```sh
tailscale status
```

## kyber (Ubuntu)

Uses the custom home-manager module (`home-manager/modules/tailscale/`), which installs a system-level `tailscaled` service via `installSystemService`:

```nix
# named-hosts/kyber/default.nix
modules.tailscale = {
  enable = true;
  installSystemService = true;
  extraUpArgs = [
    "--reset"
    "--accept-dns=false"
  ];
};
```

DNS acceptance is disabled (`--accept-dns=false`) on kyber.

### Setup

The initial bootstrap script (`named-hosts/kyber/setup.sh`) handles Tailscale installation:

```sh
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable --now tailscaled
sudo tailscale up
```

After the initial setup, subsequent rebuilds are managed via home-manager.

## MagicDNS

With all machines on the same tailnet, they resolve each other by hostname:

```sh
ping galactica
ping matic
ping kyber
```

If MagicDNS isn't working, use Tailscale IPs directly:

```sh
tailscale ip -4 galactica
tailscale ip -4 matic
tailscale ip -4 kyber
```

## Useful commands

```sh
tailscale status          # list connected nodes
tailscale ping <host>     # check latency to a node
tailscale ip -4 <host>    # get Tailscale IPv4 address
tailscale netcheck        # diagnose connectivity
```
