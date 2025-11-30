# Tailscale Setup and Usage Guide

This guide covers the setup, configuration, and usage of Tailscale VPN in this dotfiles repository.

## Overview

Tailscale is configured as a home-manager module that provides secure, private networking between your devices. The setup includes:

- Automatic service management via launchd (macOS) or systemd (Linux)
- Secure authentication key management using agenix
- Personal device connectivity configuration
- Network monitoring and management tools

## Prerequisites

- Tailscale account (free tier is sufficient for personal use)
- Admin access to your machine for service installation
- SSH key pair configured for agenix secrets management

## Initial Setup

### 1. Create a Tailscale Account

If you don't have a Tailscale account:

1. Visit [https://login.tailscale.com/start](https://login.tailscale.com/start)
2. Sign up with your preferred authentication method (Google, GitHub, Microsoft, etc.)
3. Complete the account setup process

### 2. Generate an Auth Key

1. Log in to the [Tailscale Admin Console](https://login.tailscale.com/admin)
2. Navigate to **Settings** → **Keys** in the left sidebar
3. Click **Generate auth key**
4. Configure the key settings:
   - **Description**: `galactica-macbook` (or your device name)
   - **Expiry**: `90 days` (recommended for personal use)
   - **Ephemeral**: `No` (for persistent device)
   - **Pre-approved**: `Yes` (for automatic connection)
   - **Tags**: Leave empty for personal use
5. Click **Generate key**
6. **Important**: Copy the auth key immediately as it won't be shown again

### 3. Encrypt the Auth Key

Save your auth key to a temporary file and encrypt it:

```bash
# Save auth key to temporary file
echo "tskey-auth-xxxxxxxxxxxxxxxxxxxxxxxx" > /tmp/tailscale-auth.txt

# Encrypt the key for your host
make encrypt-key-galactica KEY_FILE=/tmp/tailscale-auth.txt

# Clean up the temporary file
rm /tmp/tailscale-auth.txt
```

## Configuration

### Module Options

The Tailscale module supports the following configuration options:

```nix
services.tailscale = {
  enable = true;                    # Enable Tailscale service
  acceptRoutes = false;             # Accept advertised routes (default: false)
  advertiseExitNode = false;        # Advertise as exit node (default: false)
  useExitNode = "";                 # Exit node to use (default: none)
  authKey = "";                     # Auth key as string (alternative to authKeyFile)
  authKeyFile = "";                 # Path to auth key file (recommended)
  extraUpArgs = [                   # Additional arguments for tailscale up
    "--reset"
    "--accept-dns=false"
  ];
};
```

### Current Configuration

The galactica host is configured for personal device connectivity:

- **Authentication**: Uses encrypted auth key stored in agenix
- **Routes**: Does not accept or advertise routes
- **Exit Node**: Not configured as or using exit nodes
- **DNS**: Maintains local DNS settings
- **State**: Clean state on each restart

## Deployment

### Apply Configuration

```bash
# Build and switch to the new configuration
make switch-galactica

# Or for auto-detected host
make switch
```

### Verify Installation

```bash
# Check Tailscale status
tailscale status

# Check service status (macOS)
launchctl list | grep tailscale

# Check service status (Linux)
systemctl --user status tailscaled
```

## Usage

### Basic Commands

```bash
# Show connection status
tailscale status

# Show IP addresses
tailscale ip -4
tailscale ip -6

# List all devices in your network
tailscale status --self=false

# Ping another device
tailscale ping device-name

# Open Tailscale admin console
tailscale browse
```

### Network Access

Once connected, you can access other devices using:

- **Magic DNS**: `device-name.tailnet-name.ts.net`
- **Direct IP**: Use the IP shown in `tailscale status`

Example:
```bash
# Access another device via Magic DNS
ssh user@device-name.tailnet-name.ts.net

# Access via direct IP
ssh user@100.x.x.x
```

## Management

### Service Management

```bash
# Restart Tailscale service (macOS)
launchctl kickstart -k homebrew.mxcl.tailscaled

# Restart Tailscale service (Linux)
systemctl --user restart tailscaled

# Disconnect from Tailscale
tailscale down

# Reconnect to Tailscale
tailscale up
```

### Log Files

Log files are stored in `~/.local/share/tailscale/`:

- `tailscaled.log` - Main daemon logs
- `tailscaled.error.log` - Error logs
- `tailscale-up.log` - Connection logs
- `tailscale-up.error.log` - Connection error logs

## Troubleshooting

### Common Issues

#### 1. Authentication Fails

**Symptoms**: Service starts but shows "Not connected" in status

**Solutions**:
```bash
# Check if auth key is properly decrypted
ls -la /run/agenix/keys/tailscale-auth.age

# Manually authenticate
tailscale up --authkey=your-auth-key

# Check service logs
tail -f ~/.local/share/tailscale/tailscale-up.error.log
```

#### 2. Service Won't Start

**Symptoms**: Service fails to start or crashes immediately

**Solutions**:
```bash
# Check permissions on state directory
ls -la ~/.local/share/tailscale/

# Reset Tailscale state
rm -rf ~/.local/share/tailscale/tailscaled.state
make switch-galactica

# Check system logs (macOS)
log show --predicate 'process == "tailscaled"' --last 1h
```

#### 3. Network Connectivity Issues

**Symptoms**: Can't reach other devices or internet

**Solutions**:
```bash
# Check network status
tailscale netcheck

# Test connectivity to Tailscale servers
tailscale ping 100.100.100.100

# Reset network configuration
tailscale down
tailscale up --reset
```

### Debug Mode

Enable debug logging for troubleshooting:

```bash
# Stop the service
launchctl stop homebrew.mxcl.tailscaled

# Start manually with debug flags
tailscaled --debug --state=~/.local/share/tailscale/tailscaled.state
```

## Security Best Practices

### Auth Key Management

1. **Use non-ephemeral keys** for persistent devices
2. **Set reasonable expiry** (30-90 days for personal use)
3. **Rotate keys regularly** using the admin console
4. **Store keys securely** using agenix encryption

### Network Security

1. **Disable exit nodes** unless specifically needed
2. **Use ACLs** for access control in larger networks
3. **Monitor connections** regularly via admin console
4. **Keep software updated** with `make update`

### Privacy

1. **Magic DNS** is enabled by default for convenience
2. **Local DNS settings** are preserved (`--accept-dns=false`)
3. **No route acceptance** prevents unwanted network exposure

## Advanced Configuration

### Custom Tags and ACLs

For more complex setups, you can configure tags and ACLs:

```nix
services.tailscale = {
  enable = true;
  authKeyFile = config.age.secrets."keys/tailscale-auth.age".path;
  extraUpArgs = [
    "--reset"
    "--accept-dns=false"
    "--tag=tag:server"
  ];
};
```

### Exit Node Usage

To use an exit node (when needed):

```nix
services.tailscale = {
  enable = true;
  useExitNode = "exit-node-name";
  # ... other options
};
```

### Multiple Networks

For users with multiple Tailscale networks:

```nix
services.tailscale = {
  enable = true;
  authKeyFile = config.age.secrets."keys/tailscale-auth.age".path;
  extraUpArgs = [
    "--reset"
    "--accept-dns=false"
    "--login-server=https://login.tailscale.com"
  ];
};
```

## Integration with Other Services

### SSH Configuration

Tailscale works seamlessly with SSH. Consider adding to your SSH config:

```sshconfig
Host *.ts.net
  User your-username
  IdentityFile ~/.ssh/id_ed25519
  StrictHostKeyChecking no
  UserKnownHostsFile ~/.ssh/known_hosts.tailscale
```

### Development Tools

Many development tools work transparently with Tailscale:

- **Docker**: Containers can access Tailscale network
- **VS Code**: Remote SSH via Tailscale addresses
- **Git**: Access private repositories over Tailscale

## Maintenance

### Regular Tasks

1. **Monthly**: Check auth key expiry and rotate if needed
2. **Quarterly**: Review connected devices in admin console
3. **As needed**: Update configuration with `make switch-galactica`

### Updates

```bash
# Update entire dotfiles (includes Tailscale updates)
make update

# Update only Tailscale package
nix flake update
make switch-galactica
```

## Support

- **Tailscale Documentation**: [https://tailscale.com/kb/](https://tailscale.com/kb/)
- **Tailscale Support**: [https://support.tailscale.com/](https://support.tailscale.com/)
- **Community**: [https://github.com/tailscale/tailscale/discussions](https://github.com/tailscale/tailscale/discussions)

## File Locations

- **Module**: `home-manager/modules/tailscale/default.nix`
- **Configuration**: `named-hosts/galactica/default.nix`
- **Secrets**: `named-hosts/galactica/secrets.nix`
- **Auth Key**: `named-hosts/galactica/keys/tailscale-auth.age` (encrypted)
- **State**: `~/.local/share/tailscale/`
- **Logs**: `~/.local/share/tailscale/*.log`