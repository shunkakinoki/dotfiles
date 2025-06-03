#!/bin/sh

# Exit on error
set -e
NIX_PROFILE_TO_SOURCE=""

# Determine OS using uname
OS_NAME=$(uname)
case "$OS_NAME" in
Darwin)
  OS="macos"
  ;;
Linux)
  OS="linux"
  ;;
*)
  echo "Unsupported operating system: $OS_NAME"
  exit 1
  ;;
esac

# Install Nix if not already installed
if ! command -v nix >/dev/null 2>&1; then
  echo "Installing Nix..."
  if [ "$OS" = "macos" ]; then
    curl -L https://nixos.org/nix/install | bash
    # For macOS, source the Nix profile immediately to update PATH in CI.
    # shellcheck disable=SC1090 disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    NIX_PROFILE_TO_SOURCE="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  else # Linux
    if [ "$IN_DOCKER" = "true" ]; then
      echo "Performing single-user Nix installation (Docker environment)..."
      curl -L https://nixos.org/nix/install | bash -s -- --no-daemon
      # Source the Nix profile for single-user installation
      # shellcheck disable=SC1090 disable=SC1091
      . "$HOME/.nix-profile/etc/profile.d/nix.sh"
      NIX_PROFILE_TO_SOURCE="$HOME/.nix-profile/etc/profile.d/nix.sh"
    else
      echo "Performing multi-user Nix installation..."
      curl -L https://nixos.org/nix/install | bash -s -- --daemon
      # For Linux multi-user installations, source the Nix profile script
      # This makes 'nix' command available in the current script execution.
      _NIX_DAEMON_PROFILE="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
      if [ -f "$_NIX_DAEMON_PROFILE" ]; then
        # shellcheck disable=SC1090 disable=SC1091
        . "$_NIX_DAEMON_PROFILE"
        NIX_PROFILE_TO_SOURCE="$_NIX_DAEMON_PROFILE"
      fi
    fi
    # The sourcing above handles PATH and other environment variables.
  fi
fi

# Clone the dotfiles repository
DOTFILES_DIR="$HOME/dotfiles"
echo "Fetching the dotfiles repository..."

# If GITHUB_PR is set, handle checkout for the PR branch
if [ -n "$GITHUB_PR" ]; then
  echo "Detected PR environment variable GITHUB_PR=$GITHUB_PR"
  PR_REF="refs/pull/${GITHUB_PR}/head"
  echo "Fetching pull request ref: $PR_REF"

  if [ -d "$DOTFILES_DIR" ]; then
    echo "Dotfiles repository already exists. Using git fetch to retrieve PR ref..."
    cd "$DOTFILES_DIR"
    git fetch origin "$PR_REF":pr-"$GITHUB_PR"
    git checkout pr-"$GITHUB_PR"
    git pull
  else
    echo "Cloning dotfiles repository..."
    git clone https://github.com/shunkakinoki/dotfiles.git "$DOTFILES_DIR"
    cd "$DOTFILES_DIR"
    git fetch origin "$PR_REF":pr-"$GITHUB_PR"
    git checkout pr-"$GITHUB_PR"
  fi
else
  if [ -d "$DOTFILES_DIR" ]; then
    echo "Dotfiles repository already exists. Fetching latest changes..."
    cd "$DOTFILES_DIR"
    git fetch origin
    git pull
  else
    echo "Cloning dotfiles repository into $DOTFILES_DIR..."
    git clone https://github.com/shunkakinoki/dotfiles.git "$DOTFILES_DIR"
    cd "$DOTFILES_DIR"
  fi
fi

# Handle `make` installation
if ! command -v make >/dev/null 2>&1; then
  echo "Installing make..."
  if [ "$OS" = "macos" ]; then
    brew install make
  else
    sudo apt-get install make
  fi
fi

# Install Nix packages
echo "Running installation commands..."
if [ -n "$NIX_PROFILE_TO_SOURCE" ] && [ -f "$NIX_PROFILE_TO_SOURCE" ]; then
  echo "Running make install within a bash subshell with Nix profile $NIX_PROFILE_TO_SOURCE sourced..."
  bash -c ". "$NIX_PROFILE_TO_SOURCE" && make install"
else
  echo "Running make install directly (Nix presumed to be in PATH or not needed by make)..."
  make install
fi
