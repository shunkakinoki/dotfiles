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

# 1b. Install the system C/C++ toolchain
#
# Kyber runs Ubuntu with nix layered on top, so ~/.nix-profile/bin shadows the
# system compiler. node-gyp would then link native addons (node-pty) against the
# nix glibc while the runtime node -- a generic build from fnm -- uses the system
# loader, so dlopen fails with `GLIBC_2.42 not found` even though the .node file
# exists. Ubuntu ships gcc but not g++, which is what forces that fallback.
# build-essential provides gcc, g++, make and libc6-dev against the system glibc.
echo "📦 Installing build toolchain (node-gyp needs a system g++)..."
if ! [ -x /usr/bin/g++ ]; then
  sudo apt-get update
  sudo apt-get install -y build-essential
fi
if ! [ -x /usr/bin/g++ ]; then
  echo "❌ /usr/bin/g++ still missing; native node addons will not load" >&2
  exit 1
fi

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
