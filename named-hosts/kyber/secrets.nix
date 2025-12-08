# Kyber secrets - managed by agenix
# To add a new secret:
# 1. Add the secret definition here
# 2. Run: make encrypt-key-kyber KEY_FILE=/path/to/secret
{
  # Tailscale auth key - generate from https://login.tailscale.com/admin/settings/keys
  # "keys/tailscale-auth.age" = {
  #   file = ./keys/tailscale-auth.age;
  #   publicKeys = [
  #     # Kyber's SSH public key (run: ssh ubuntu@kyber "cat ~/.ssh/id_ed25519.pub")
  #     "ssh-ed25519 AAAA..."
  #   ];
  # };

  # SSH key sync (your local key encrypted for kyber)
  # "keys/id_ed25519.age" = {
  #   file = ./keys/id_ed25519.age;
  #   publicKeys = [
  #     "ssh-ed25519 AAAA..."
  #   ];
  # };
}
