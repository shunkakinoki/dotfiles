# syntax=docker/dockerfile:1.7

# Stage 1: download actions/runner agent + container hooks + docker CLI/buildx
# so the final image can be used as a custom ARC runner image with the
# canonical /home/runner layout (matches GitHub-hosted runners and the
# upstream actions/runner Dockerfile).
FROM ubuntu:26.04 AS runner-build
ARG TARGETOS=linux
ARG TARGETARCH
ARG RUNNER_VERSION=2.334.0
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.7.0
ARG DOCKER_VERSION=29.4.0
ARG BUILDX_VERSION=0.33.0

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /actions-runner
RUN RUNNER_ARCH=${TARGETARCH}; [ "$RUNNER_ARCH" = "amd64" ] && RUNNER_ARCH=x64; \
    curl -fL -o runner.tar.gz \
      https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-${TARGETOS}-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf runner.tar.gz \
    && rm runner.tar.gz

RUN curl -fL -o hooks.zip \
      https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
    && unzip hooks.zip -d ./k8s \
    && rm hooks.zip

RUN DOCKER_ARCH=x86_64; [ "$TARGETARCH" = "arm64" ] && DOCKER_ARCH=aarch64; \
    curl -fLo docker.tgz https://download.docker.com/${TARGETOS}/static/stable/${DOCKER_ARCH}/docker-${DOCKER_VERSION}.tgz \
    && tar zxf docker.tgz \
    && rm docker.tgz \
    && mkdir -p /usr/local/lib/docker/cli-plugins \
    && curl -fLo /usr/local/lib/docker/cli-plugins/docker-buildx \
       https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-${TARGETARCH} \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

FROM ubuntu:26.04

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
    openssh-server \
    sudo \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd

# Create a non-root user for running the setup and for the agent.
# The agent will run as this user.
ARG USER=runner
ARG USER_UID=1001
ARG USER_GID=$USER_UID
ARG COMMIT_SHA=main
ARG GITHUB_TOKEN
ARG GITHUB_PR
ENV GITHUB_PR=${GITHUB_PR}

RUN set -e; \
    groupadd --gid $USER_GID $USER; \
    useradd --uid $USER_UID --gid $USER_GID --shell /bin/bash --create-home $USER; \
    usermod -aG nix-users $USER; \
    id $USER
RUN echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER \
    && chmod 0440 /etc/sudoers.d/$USER

# Place actions/runner agent at /home/runner (canonical layout, matches
# GitHub-hosted runners and the upstream actions/runner Dockerfile). docker
# group GID 123 matches the standard ARC dind sidecar GID.
RUN groupadd --gid 123 docker && usermod -aG docker $USER
COPY --chown=$USER:docker --from=runner-build /actions-runner/. /home/$USER/
COPY --from=runner-build /usr/local/lib/docker/cli-plugins/docker-buildx /usr/local/lib/docker/cli-plugins/docker-buildx
RUN install -o root -g root -m 755 /home/$USER/docker/* /usr/bin/ \
 && rm -rf /home/$USER/docker

ENV RUNNER_MANUALLY_TRAP_SIG=1 \
    ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1 \
    ImageOS=ubuntu26

ENV NIX_BUILD_GROUP_ID=1001
ENV IN_DOCKER=true

# We must start the daemon and run the installation in the same RUN command
# so that the daemon is available for the Nix commands in the script.
RUN mkdir -p /etc/nix && \
    echo "trusted-users = root $USER" > /etc/nix/nix.conf && \
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf && \
    echo "filter-syscalls = false" >> /etc/nix/nix.conf && \
    echo "sandbox = true" >> /etc/nix/nix.conf && \
    if [ -n "$GITHUB_TOKEN" ]; then \
      echo "access-tokens = github.com=$GITHUB_TOKEN" >> /etc/nix/nix.conf ; \
    fi

RUN /usr/bin/nix-daemon & \
    sleep 5 && \
    # Run your dotfiles installation script.
    # This script is expected to install fish and other tools.
    # Make sure this script is idempotent or handles being run in a fresh environment.
    sudo -u $USER -E -H bash -c "curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/$COMMIT_SHA/install.sh | bash"

# Switch to the non-root user
USER $USER
WORKDIR /home/$USER

# Run your dotfiles installation script
# This script is expected to install fish and other tools.
# Make sure this script is idempotent or handles being run in a fresh environment.
# RUN curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/$COMMIT_SHA/install.sh | /bin/bash

# Your install.sh script should ideally set up fish as the default shell if desired.
RUN sudo chsh -s $(which fish) $USER
# Or, to set fish as the default shell for subsequent Dockerfile commands and for the agent's shell:
SHELL ["/usr/bin/fish", "-l", "-c"]

EXPOSE 22

# slep infinity keeps the container alive
CMD ["sleep", "infinity"]
