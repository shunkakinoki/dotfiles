FROM ubuntu:24.04

# Set DEBIAN_FRONTEND to noninteractive to avoid prompts during package installations
ENV DEBIAN_FRONTEND=noninteractive

# Install only the essentials needed for the installer and build.
# - xz-utils is required by the Nix installer
# - sudo is required since the script uses it
RUN apt-get update && apt-get install -y \
    build-essential \
    bzip2 \
    ca-certificates \
    curl \
    git \
    make \
    sudo \
    xz-utils \
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

ENV NIX_BUILD_GROUP_ID=1001
ENV IN_DOCKER=true

# Run the installer as the non-root user in single-user mode (handled by install.sh via IN_DOCKER)
USER $USER
WORKDIR /home/$USER
RUN bash -lc "curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/$COMMIT_SHA/install.sh | bash"

# Run your dotfiles installation script
# This script is expected to install fish and other tools.
# Make sure this script is idempotent or handles being run in a fresh environment.
# RUN curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/$COMMIT_SHA/install.sh | /bin/bash

# Your install.sh script should ideally set up fish as the default shell if desired.
# If it doesn't, you might need to add a line here like:
# RUN sudo chsh -s $(which fish) $USER
# Or, to set fish as the default shell for subsequent Dockerfile commands and for the agent's shell:
SHELL ["/usr/bin/fish", "-l", "-c"]
