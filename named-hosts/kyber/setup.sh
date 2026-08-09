#!/bin/bash

# Kyber (Ubuntu) Initial Setup Script
# Run this on the Kyber server to bootstrap the environment
#
# Supply-chain note: the Tailscale installer is fetched over HTTPS from the
# vendor. Prefer verifying the published checksum/signature from
# https://tailscale.com/download when bootstrapping a production host.

set -e

echo "🚀 Setting up Kyber server..."

# 1. Install cron
echo "📦 Installing cron..."
if ! command -v crontab &>/dev/null; then
  sudo apt-get update
  sudo apt-get install -y cron
fi
sudo systemctl enable --now cron

# 2. Install Tailscale
echo "📦 Installing Tailscale..."
if ! command -v tailscale &>/dev/null; then
  echo "Fetching Tailscale installer (verify vendor checksums for production)..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi

# 3. Enable and start Tailscale daemon
echo "🔧 Enabling Tailscale daemon..."
sudo systemctl enable --now tailscaled

# 4. Connect to Tailscale (will prompt for auth)
echo "🔗 Connecting to Tailscale..."
sudo tailscale up

# 5. Verify Tailscale connection
echo "✅ Tailscale status:"
tailscale status
