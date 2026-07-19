# Andor Host Configuration

Andor is an Ubuntu VPS running an independent single-node k3s cluster for the
external API workload profile. It is not a Kyber agent and does not share an
etcd control plane with Kyber.

## Bootstrap

Set the VPS hostname to `andor`, install Tailscale and Nix, then apply the named
Home Manager configuration:

```bash
sudo hostnamectl set-hostname andor
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable --now tailscaled
sudo tailscale up --accept-dns=false --ssh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux
git clone https://github.com/shunkakinoki/dotfiles ~/dotfiles
cd ~/dotfiles
make switch HOST=andor
```

The host configuration installs k3s and labels the node with the
`external-api` workload profile. Kubernetes applications are selected by the
Andor Argo CD overlay in `shunkakinokisoftware`; dotfiles never deploys the full
production application set.
