#!/bin/bash

# Kyber (Ubuntu) Initial Setup Script
# Run this on the Kyber server to bootstrap the environment

set -e

echo "🚀 Setting up Kyber server..."

# 1. Install Tailscale
echo "📦 Installing Tailscale..."
if ! command -v tailscale &>/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

# 2. Enable and start Tailscale daemon
echo "🔧 Enabling Tailscale daemon..."
sudo systemctl enable --now tailscaled

# 3. Connect to Tailscale (will prompt for auth)
echo "🔗 Connecting to Tailscale..."
sudo tailscale up

# 4. Verify Tailscale connection
echo "✅ Tailscale status:"
tailscale status
