#!/usr/bin/env bash
# Remotely rekey galactica secrets to include kyber's public key
# This script should be run from kyber to trigger the rekey on galactica

set -e

echo "🔑 Rekeying galactica secrets to include kyber..."
echo ""
echo "This will:"
echo "1. Connect to galactica via Tailscale SSH"
echo "2. Run the rekey command to re-encrypt secrets with both keys"
echo "3. Commit and push the changes"
echo ""

# Try Tailscale SSH first
if tailscale ssh shunkakinoki@galactica "cd ~/dotfiles && make rekey-galactica" 2>/dev/null; then
  echo "✅ Rekey completed via Tailscale SSH"
else
  echo "❌ Tailscale SSH failed. Please run this manually on galactica:"
  echo ""
  echo "  cd ~/dotfiles"
  echo "  git pull"
  echo "  make rekey-galactica"
  echo "  git add named-hosts/galactica/keys/"
  echo "  git commit -m 'chore(agenix): rekey secrets for kyber access'"
  echo "  git push"
  echo ""
  exit 1
fi

# Pull the changes
echo ""
echo "📥 Pulling re-encrypted secrets..."
cd ~/dotfiles
git pull

echo ""
echo "✅ Done! Now run: make switch"
