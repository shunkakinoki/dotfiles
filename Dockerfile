FROM ubuntu:24.04

# Set DEBIAN_FRONTEND to noninteractive to avoid prompts during package installations
ENV DEBIAN_FRONTEND=noninteractive

# Install basic dependencies that are often required for setup scripts.
# Your specific install.sh script might need others.
# ca-certificates is important for curl/git over https.
# sudo is needed if the script uses it internally without installing it.
# git is likely used by your dotfiles script.
RUN apt-get update && apt-get install -y \
    build-essential \
    bzip2 \
    ca-certificates \
    curl \
    git \
    make \
    sudo \
    xz-utils \
    # Add any other system-level dependencies your script needs here
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for running the setup and for the agent.
# The agent will run as this user.
ARG USER=runner
ARG USER_UID=1001
ARG USER_GID=$USER_UID
ARG COMMIT_SHA=main

RUN set -e; \
    groupadd --gid $USER_GID $USER; \
    useradd --uid $USER_UID --gid $USER_GID --shell /bin/bash --create-home $USER; \
    id $USER
RUN echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER \
    && chmod 0440 /etc/sudoers.d/$USER

ENV IN_DOCKER=true

# Install Nix in multi-user mode
RUN sh <(curl -L https://nixos.org/nix/install) --daemon --yes

# Configure Nix
RUN mkdir -p /etc/nix && \
    echo "trusted-users = root $USER" > /etc/nix/nix.conf && \
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf && \
    echo "filter-syscalls = false" >> /etc/nix/nix.conf && \
    echo "sandbox = false" >> /etc/nix/nix.conf

# Run the dotfiles installation script
# This script is expected to install fish and other tools.
RUN . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && \
    sudo -u $USER -E -H bash -c "curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/$COMMIT_SHA/install.sh | bash"

# Switch to the non-root user
USER $USER
WORKDIR /home/$USER

# Set up environment for Nix
ENV PATH="/nix/var/nix/profiles/default/bin:$PATH"

# The default shell remains bash as fish is installed via Nix and its path
# varies based on the installation. Users can change their shell preference
# in their dotfiles configuration.
