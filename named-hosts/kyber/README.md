# Kyber Host Configuration

Ubuntu Linux server managed via home-manager with Tailscale VPN.

## Initial Setup

On the Kyber server, run:

```bash
# 1. Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable --now tailscaled
sudo tailscale up

# 2. Install Nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux

# 3. Clone dotfiles
git clone https://github.com/shunkakinoki/dotfiles ~/dotfiles
cd ~/dotfiles

# 4. Apply configuration
make switch
```

## Managing Secrets

### Get Kyber's SSH public key

```bash
ssh ubuntu@kyber "cat ~/.ssh/id_ed25519.pub"
```

Add this key to `secrets.nix`, then encrypt secrets:

```bash
# Encrypt Tailscale auth key
make encrypt-key-kyber KEY_FILE=/path/to/tailscale-auth-key.txt

# Verify
make decrypt-key-kyber KEY_FILE=tailscale-auth
```

## SSH Access

Once Tailscale is set up:

```bash
kyber  # Fish abbreviation that runs: ssh ubuntu@kyber
```

## SSH Key Management

### Automated Setup

This configuration uses:

- **agenix**: Encrypts and syncs the GitHub SSH key from galactica
- **keychain**: Manages ssh-agent and automatically loads SSH keys
- **Declarative deployment**: SSH keys are deployed during `make switch`

### Syncing SSH Keys from Galactica

#### On Galactica (one-time setup)

```bash
cd ~/dotfiles
git pull
make rekey-galactica
git add named-hosts/galactica/keys/
git commit -m "chore(agenix): rekey secrets for kyber access"
git push
```

#### On Kyber

```bash
cd ~/dotfiles
git pull
make switch
```

The GitHub SSH key will be automatically:

1. Decrypted from `named-hosts/galactica/keys/id_ed25519.age`
2. Deployed to `~/.ssh/id_ed25519_github`
3. Loaded into ssh-agent via keychain (if no passphrase)

### Adding Passphrase-Protected Keys

If the GitHub SSH key has a passphrase, add it manually:

```bash
sag  # Abbreviation for _ssh_add_github function

# Or manually
keychain --eval --quiet --confirm ~/.ssh/id_ed25519_github
```

### Verify GitHub Access

```bash
ssh -T git@github.com
# Expected: Hi username! You've successfully authenticated...
```

### Troubleshooting

**Key not deployed after `make switch`:**

```bash
# Check if key exists
ls -la ~/.ssh/id_ed25519_github

# Manually deploy if needed
age -d -i ~/.ssh/id_ed25519 -o ~/.ssh/id_ed25519_github \
  named-hosts/galactica/keys/id_ed25519.age
chmod 0600 ~/.ssh/id_ed25519_github
```

**GitHub authentication fails:**

```bash
# Check if key is in ssh-agent
ssh-add -l | grep github

# Add the key
sag
```
