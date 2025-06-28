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
    daemon \
    git \
    make \
    nix-setup-systemd \
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
    usermod -aG nix-users $USER; \
    id $USER
RUN echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER \
    && chmod 0440 /etc/sudoers.d/$USER

ENV NIX_BUILD_GROUP_ID=1001
ENV IN_DOCKER=true

# Prepare Nix config, start daemon, and run install script in one go.
# We must start the daemon, give it a moment to initialize, then run the installation as the non-root user.
# All within a single RUN command so the daemon process persists for the duration of the command.
RUN mkdir -p /etc/nix && \
    echo "trusted-users = root $USER" > /etc/nix/nix.conf && \
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf && \
    /usr/bin/nix-daemon & \
    sleep 5 && \
    # Run your dotfiles installation script.
    # This script is expected to install fish and other tools.
    # Make sure this script is idempotent or handles being run in a fresh environment.
    sudo -u $USER -E -H bash -c "curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/$COMMIT_SHA/install.sh | bash"

# Switch to the non-root user for subsequent commands
USER $USER
WORKDIR /home/$USER

# Run your dotfiles installation script
# This script is expected to install fish and other tools.
# Make sure this script is idempotent or handles being run in a fresh environment.
# RUN curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/$COMMIT_SHA/install.sh | /bin/bash

# Your install.sh script should ideally set up fish as the default shell if desired.
# If it doesn't, you might need to add a line here like:
# RUN sudo chsh -s $(which fish) $USER
# Or, to set fish as the default shell for subsequent Dockerfile commands and for the agent's shell:
SHELL ["/usr/bin/fish", "-l", "-c"]
