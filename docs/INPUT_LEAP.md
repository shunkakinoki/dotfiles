# Input Leap

Input Leap shares keyboard and mouse between machines over the network. Traffic flows over Tailscale (WireGuard-encrypted), so Input Leap's own TLS is disabled.

## Architecture

| Machine | Role | Service type |
|---|---|---|
| galactica | Server (shares keyboard/mouse) | launchd agent |
| matic | Client (receives input) | systemd user service |
| kyber | Not configured (headless server) | N/A |

## Config files

| File | Purpose |
|---|---|
| `config/input-leap/server.conf` | Screen layout and hotkeys |
| `config/input-leap/default.nix` | Deploys server config to galactica |
| `home-manager/services/input-leap/default.nix` | Server (launchd) and client (systemd) services |

## Screen layout

```
[ galactica ] --right--> [ matic ]
[ matic ]     --left-->  [ galactica ]
```

Defined in `config/input-leap/server.conf`. Edit `right`/`left`/`up`/`down` to match physical monitor positions.

## Hotkeys

- `Super+Shift+Left` — switch to left screen
- `Super+Shift+Right` — switch to right screen

## Setup

### 1. Deploy

**galactica:**
```sh
make switch-galactica
```

**matic:**
```sh
make build HOST=matic && make switch HOST=matic
```

### 2. Verify Tailscale connectivity

Both machines must be on the same tailnet:

```sh
tailscale ping galactica  # from matic
tailscale ping matic      # from galactica
```

### 3. Services start automatically

- **galactica**: launchd starts `input-leaps` on `:24800`
- **matic**: systemd starts `input-leapc` connecting to `galactica:24800`

## Troubleshooting

### Check server logs (galactica)

```sh
cat /tmp/input-leap-server.log
cat /tmp/input-leap-server.error.log
```

### Check client logs (matic)

```sh
journalctl --user -u input-leap-client -f
```

### Restart services

**galactica:**
```sh
launchctl kickstart -k gui/$(id -u)/org.nix-community.home.input-leap-server
```

**matic:**
```sh
systemctl --user restart input-leap-client
```

### MagicDNS not resolving

If `galactica` doesn't resolve from matic, use the Tailscale IP:

```sh
# Get galactica's Tailscale IP
tailscale ip -4 galactica
```

Then update `home-manager/services/input-leap/default.nix` to use the IP instead of the hostname.

### macOS accessibility permissions

Input Leap needs Accessibility permissions on macOS to control keyboard/mouse. On first run, macOS will prompt to grant access in System Settings > Privacy & Security > Accessibility.

### Wayland/X11

The client on matic runs under Hyprland (Wayland). Input Leap's Wayland support requires `libei`. If input doesn't work, check that `input-leap` was built with `libei` support.
