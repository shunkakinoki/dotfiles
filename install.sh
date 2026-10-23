#!/bin/sh

# Exit on error
set -e

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

# Fresh Ubuntu images may only provide root. Provision the account used by the
# Beskar profile before handing off checkout and activation to that account.
prepare_beskar_user() {
  if ! command -v runuser >/dev/null 2>&1 \
    || ! command -v useradd >/dev/null 2>&1 \
    || ! command -v sudo >/dev/null 2>&1 \
    || ! command -v visudo >/dev/null 2>&1 \
    || [ ! -f /usr/lib/systemd/user/dbus.socket ]; then
    if ! command -v apt-get >/dev/null 2>&1; then
      echo "Beskar root bootstrap requires apt-get to install account and user-session prerequisites." >&2
      exit 1
    fi
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
      sudo passwd util-linux dbus-user-session
  fi

  if ! getent passwd ubuntu >/dev/null; then
    echo "Creating the ubuntu account and home directory for Beskar..."
    useradd --create-home --shell /bin/bash ubuntu
  fi
  _ubuntu_entry=$(getent passwd ubuntu)
  INSTALL_HOME=$(printf '%s\n' "$_ubuntu_entry" | cut -d: -f6)
  INSTALL_UID=$(printf '%s\n' "$_ubuntu_entry" | cut -d: -f3)
  if [ -z "$INSTALL_HOME" ] || [ "$INSTALL_HOME" = /root ] || [ "$INSTALL_UID" = 0 ] || [ ! -d "$INSTALL_HOME" ]; then
    echo "Beskar's ubuntu account must have a non-root uid and an existing home directory outside /root." >&2
    exit 1
  fi

  # Activation installs system services non-interactively. Retain existing
  # working sudo access; otherwise install one validated account-specific rule.
  if ! runuser -u ubuntu -- sudo -n true 2>/dev/null; then
    echo "Configuring passwordless administrative access for ubuntu on Beskar..."
    (
      umask 077
      install -d -m 0755 /etc/sudoers.d
      _sudoers_tmp=$(mktemp /etc/sudoers.d/.dotfiles-beskar-ubuntu.XXXXXX)
      trap 'rm -f "$_sudoers_tmp"' 0
      printf '%s\n' 'ubuntu ALL=(ALL:ALL) NOPASSWD: ALL' >"$_sudoers_tmp"
      visudo -cf "$_sudoers_tmp"
      chmod 0440 "$_sudoers_tmp"
      mv -f "$_sudoers_tmp" /etc/sudoers.d/dotfiles-beskar-ubuntu
    )
    runuser -u ubuntu -- sudo -n true
  fi

  if [ "$(cat /proc/1/comm 2>/dev/null)" = systemd ]; then
    loginctl enable-linger ubuntu
    systemctl start "user@$INSTALL_UID.service"
  fi
}

# Beskar's Home Manager profile belongs to ubuntu even when bootstrap is
# launched from a root SSH session. Do not merely change USER: activation must
# run with ubuntu's real uid, home directory, and user-service environment.
INSTALL_AS_UBUNTU=false
INSTALL_HOME=$HOME
_install_host=$(printf '%s' "${HOST:-$(hostname)}" | tr '[:upper:]' '[:lower:]')
if [ "$OS" = linux ] && [ "${_install_host%%.*}" = beskar ]; then
  HOST=beskar
  export HOST
  _current_user=$(id -un)
  if [ "$(id -u)" = 0 ]; then
    prepare_beskar_user
    INSTALL_AS_UBUNTU=true
  elif [ "$_current_user" != ubuntu ]; then
    echo "Run Beskar bootstrap as ubuntu or root." >&2
    exit 1
  else
    USER=ubuntu
    export USER
  fi
fi

# Named Kamino machines share one generated Linux/root profile family.
KAMINO_INSTALL=false
_normalized_host=$(printf '%s' "${HOST:-}" | tr '[:upper:]' '[:lower:]')
case "$_normalized_host" in
kamino*)
  if ! printf '%s\n' "$_normalized_host" | grep -Eq '^kamino([1-9][0-9]*)?$'; then
    echo "Invalid Kamino name: use kamino or kamino1, kamino2, ..." >&2
    exit 1
  fi
  if [ "$OS" != linux ] || [ "$(uname -m)" != x86_64 ] || [ "$(id -u)" != 0 ]; then
    echo "Kamino installation requires root on x86_64 Linux." >&2
    exit 1
  fi
  if [ "$(cat /proc/1/comm 2>/dev/null)" != systemd ]; then
    echo "Kamino services require systemd (VPS or systemd-enabled container)." >&2
    exit 1
  fi
  if [ -f "$HOME/.config/kamino/name" ] && [ "$(cat "$HOME/.config/kamino/name")" != "$_normalized_host" ]; then
    echo "Refusing to change this machine's installed Kamino identity." >&2
    exit 1
  fi
  HOST=$_normalized_host
  USER=root
  export HOST USER
  KAMINO_INSTALL=true
  ;;
esac

run_root() {
  if [ "$(id -u)" = 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

if [ "$KAMINO_INSTALL" = true ] && [ ! -f /usr/lib/systemd/user/dbus.socket ]; then
  if command -v apt-get >/dev/null 2>&1; then
    run_root apt-get update -qq
    run_root apt-get install -y -qq dbus-user-session
  else
    echo "Install the systemd user D-Bus service before installing Kamino." >&2
    exit 1
  fi
fi

# Initialize
NIX_EFFECTIVE_BIN_PATH=""

# Ensure USER variable is set and exported
if [ -z "$USER" ]; then
  CURRENT_USER=$(id -un)
  if [ -z "$CURRENT_USER" ]; then
    echo "Warning: Could not determine current user using 'id -un'. Defaulting USER to OS_NAME."
    USER="$OS_NAME"
  else
    USER="$CURRENT_USER"
  fi
  export USER
  echo "USER variable was not set or could not be determined. Setting and exporting USER to: $USER"
else
  # Ensure USER is exported if it was already set
  export USER
  echo "USER variable is already set to: $USER. Ensuring it is exported."
fi

# Install Nix if not already installed
if ! command -v nix >/dev/null 2>&1; then
  echo "Installing Nix..."
  if [ "$OS" = "macos" ]; then
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
    # For macOS, source the Nix profile immediately to update PATH in CI.
    # shellcheck source=/dev/null
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    NIX_EFFECTIVE_BIN_PATH="/nix/var/nix/profiles/default/bin"
  else # Linux
    # Auto-detect container environment (Docker, Podman, RunPod, etc.)
    # Use /proc/1/comm instead of pidof - pidof can fail on minimal installs even when systemd is PID 1
    _init_name=$(cat /proc/1/comm 2>/dev/null || echo "unknown")
    if [ "$IN_DOCKER" = "true" ] || [ -f /.dockerenv ] || [ -f /run/.containerenv ] || [ "$_init_name" != "systemd" ]; then
      echo "Performing Determinate Nix installation (Docker environment)..."
      curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux --init none --no-confirm
      # Source the Nix profile script to add Nix to PATH for the current shell
      if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        # shellcheck source=/dev/null
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
        echo "Sourced Nix profile for Determinate Nix (Docker) setup."
      else
        echo "Warning: Nix profile script ($HOME/.nix-profile/etc/profile.d/nix.sh) not found after installation."
        # Fallback PATH export for the current shell
        export PATH="$HOME/.nix-profile/bin:$PATH"
      fi
      NIX_EFFECTIVE_BIN_PATH="$HOME/.nix-profile/bin"
    else # Linux multi-user
      echo "Performing Determinate Nix multi-user installation..."
      curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux --no-confirm
      # Start the Nix daemon so nix commands work in this session
      if command -v systemctl >/dev/null 2>&1; then
        run_root systemctl start nix-daemon.service 2>/dev/null || true
      fi
      # Source the Nix profile to add nix to PATH
      if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        # shellcheck source=/dev/null
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
      fi
      export PATH="/nix/var/nix/profiles/default/bin:$PATH"
      NIX_EFFECTIVE_BIN_PATH="/nix/var/nix/profiles/default/bin"
    fi
  fi
else
  echo "Nix is already installed."
  # Determine NIX_EFFECTIVE_BIN_PATH from existing Nix installation
  _nix_executable_path=$(command -v nix)
  if [ -n "$_nix_executable_path" ]; then
    NIX_EFFECTIVE_BIN_PATH=$(dirname "$_nix_executable_path")
    echo "Determined existing NIX_EFFECTIVE_BIN_PATH as: $NIX_EFFECTIVE_BIN_PATH"
  else
    echo "Warning: Nix is installed but 'command -v nix' failed to find it. PATH issues might persist."
    # Fallback for safety, though 'command -v nix' in the outer 'if' should have caught this.
    if [ "$OS" = "macos" ]; then
      NIX_EFFECTIVE_BIN_PATH="/nix/var/nix/profiles/default/bin"
    elif [ "$IN_DOCKER" = "true" ] || [ -f /.dockerenv ] || [ -f /run/.containerenv ] || ! pidof systemd >/dev/null 2>&1; then
      NIX_EFFECTIVE_BIN_PATH="$HOME/.nix-profile/bin"
    else
      NIX_EFFECTIVE_BIN_PATH="/nix/var/nix/profiles/default/bin"
    fi
    echo "Using fallback NIX_EFFECTIVE_BIN_PATH: $NIX_EFFECTIVE_BIN_PATH"
  fi
fi

# Ensure git is available (fresh Ubuntu minimal installs may not have it)
if ! command -v git >/dev/null 2>&1; then
  echo "git is not installed. Installing git..."
  if command -v apt-get >/dev/null 2>&1; then
    run_root apt-get update -qq && run_root apt-get install -y -qq git
  elif command -v dnf >/dev/null 2>&1; then
    run_root dnf install -y git
  elif command -v yum >/dev/null 2>&1; then
    run_root yum install -y git
  elif command -v pacman >/dev/null 2>&1; then
    run_root pacman -Sy --noconfirm git
  else
    echo "Error: Could not install git. No supported package manager found."
    exit 1
  fi
fi

# Run checkout and Home Manager commands with the profile owner's real uid.
# Keep root's XDG, D-Bus, SSH agent, and Nix profile paths out of that session.
run_install_user() {
  if [ "$INSTALL_AS_UBUNTU" = true ]; then
    _install_path="$INSTALL_HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    if [ -d "/run/user/$INSTALL_UID" ]; then
      set -- env XDG_RUNTIME_DIR="/run/user/$INSTALL_UID" "$@"
      if [ -S "/run/user/$INSTALL_UID/bus" ]; then
        set -- env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$INSTALL_UID/bus" "$@"
      fi
    fi
    set -- env -u XDG_RUNTIME_DIR -u DBUS_SESSION_BUS_ADDRESS \
      -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_STATE_HOME -u XDG_CACHE_HOME \
      -u SSH_AUTH_SOCK -u NIX_PROFILES -u NIX_USER_PROFILE_DIR \
      HOME="$INSTALL_HOME" USER=ubuntu LOGNAME=ubuntu PATH="$_install_path" \
      "$@"
    runuser -u ubuntu -- "$@"
  else
    "$@"
  fi
}

# Clone into the profile owner's home; leave any previous root checkout alone.
DOTFILES_DIR="$INSTALL_HOME/dotfiles"
cd "$INSTALL_HOME"
echo "Fetching the dotfiles repository..."

# If GITHUB_PR is set, handle checkout for the PR branch
if [ -n "$GITHUB_PR" ]; then
  echo "Detected PR environment variable GITHUB_PR=$GITHUB_PR"
  PR_REF="refs/pull/${GITHUB_PR}/head"
  echo "Fetching pull request ref: $PR_REF"

  if [ -d "$DOTFILES_DIR" ]; then
    echo "Dotfiles repository already exists. Using git fetch to retrieve PR ref..."
    cd "$DOTFILES_DIR"
    run_install_user git fetch origin "$PR_REF":pr-"$GITHUB_PR"
    run_install_user git checkout pr-"$GITHUB_PR"
    run_install_user git pull
  else
    echo "Cloning dotfiles repository..."
    run_install_user git clone https://github.com/shunkakinoki/dotfiles.git "$DOTFILES_DIR"
    cd "$DOTFILES_DIR"
    run_install_user git fetch origin "$PR_REF":pr-"$GITHUB_PR"
    run_install_user git checkout pr-"$GITHUB_PR"
  fi
else
  if [ -d "$DOTFILES_DIR" ]; then
    echo "Dotfiles repository already exists. Fetching latest changes..."
    cd "$DOTFILES_DIR"
    run_install_user git fetch origin
    run_install_user git pull
  else
    echo "Cloning dotfiles repository into $DOTFILES_DIR..."
    run_install_user git clone https://github.com/shunkakinoki/dotfiles.git "$DOTFILES_DIR"
    cd "$DOTFILES_DIR"
  fi
fi

# Use make from nixpkgs when the base system does not provide it. This avoids
# invoking the non-setuid sudo package binary on fresh NixOS machines.
if [ "$KAMINO_INSTALL" = true ]; then
  if ! nix --extra-experimental-features "nix-command flakes" eval --raw \
    ".#homeConfigurations.$HOST.config.home.username" >/dev/null; then
    echo "HOST=$HOST is not available in this checkout's generated Kamino fleet." >&2
    exit 1
  fi
fi

if ! command -v make >/dev/null 2>&1; then
  echo "make is not installed; it will be provided temporarily by nixpkgs."
fi

run_make_install() {
  if command -v make >/dev/null 2>&1; then
    HOST="$HOST" run_install_user make install
  else
    HOST="$HOST" run_install_user nix --extra-experimental-features "nix-command flakes" \
      shell nixpkgs#gnumake --command make install
  fi
}

# Install Nix packages
echo "Running installation commands..."
if [ -n "$HOST" ]; then
  echo "Forwarding HOST=$HOST to make install (overrides hostname auto-detection)."
fi
if [ -n "$NIX_EFFECTIVE_BIN_PATH" ] && [ -d "$NIX_EFFECTIVE_BIN_PATH" ]; then
  echo "Prepending $NIX_EFFECTIVE_BIN_PATH to PATH for 'make install' command."
  echo "Ensuring USER=$USER and CI=$CI are passed to make install."
  PATH="$NIX_EFFECTIVE_BIN_PATH:$PATH"
  export PATH USER CI HOST
  run_make_install
else
  echo "Warning: NIX_EFFECTIVE_BIN_PATH ('$NIX_EFFECTIVE_BIN_PATH') is not set or not a directory."
  echo "Running 'make install' with potentially incomplete PATH. Current PATH: $PATH"
  echo "Attempting to find nix via 'command -v nix': $(command -v nix || echo 'nix not found in current PATH')"
  echo "USER=$USER will be available to make install (exported)."
  run_make_install
fi
