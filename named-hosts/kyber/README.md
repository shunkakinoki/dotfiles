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

## Syncing SSH Keys from Galactica

To sync the GitHub SSH key from galactica to kyber:

### On Galactica

```bash
cd ~/dotfiles
git pull
make rekey-galactica
git add named-hosts/galactica/keys/
git commit -m "chore(agenix): rekey secrets for kyber access"
git push
```

### On Kyber

```bash
cd ~/dotfiles
git pull
make switch

# Test GitHub access
ssh -T git@github.com
```

The SSH key will be automatically decrypted and deployed to `~/.ssh/id_ed25519_github`.
