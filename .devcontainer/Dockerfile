FROM ubuntu:20.04

ARG USERNAME=shun
ARG USER_UID=1000
ARG USER_GID=$USER_UID

ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
  && apt-get -y install --no-install-recommends \
  apt-transport-https \
  apt-utils \
  build-essential \
  ca-certificates \
  cargo \
  curl \
  dialog \
  fzf \
  git \
  hub \
  gnupg \
  iproute2 \
  jq \
  less \
  libc6 \
  libgcc1 \
  libgssapi-krb5-2 \
  libicu[0-9][0-9] \
  liblttng-ust0 \
  libstdc++6 \
  locales \
  lsb-release \
  npm \
  nano \
  openssh-client \
  procps \
  software-properties-common \
  sudo \
  unzip \
  vim \
  wget \
  zlib1g \
  zsh \
  && apt-get autoremove -y \
  && rm -rf /var/lib/apt/lists/*

RUN if id -u $USERNAME > /dev/null 2>&1; then \
  if [ "$USER_GID" != "$(id -G $USERNAME)" ]; then \
  groupmod --gid $USER_GID $USERNAME; \
  usermod --gid $USER_GID $USERNAME; \
  fi; \
  if [ "$USER_UID" != "$(id -u $USERNAME)" ]; then \
  usermod --uid $USER_UID $USERNAME; \
  fi; \
  else \
  groupadd --gid $USER_GID $USERNAME; \
  useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME; \
  fi;

RUN apt-get install -y sudo; \
  echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME; \
  chmod 0440 /etc/sudoers.d/$USERNAME;

RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment \
  && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
  && echo "LANG=en_US.UTF-8" > /etc/locale.conf \
  && locale-gen en_US.UTF-8

# Temporary fix for https://unix.stackexchange.com/questions/578949/sudo-setrlimitrlimit-core-operation-not-permitted
RUN echo "Set disable_coredump false" >> /etc/sudo.conf

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - \
  && echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list \
  && apt install -y \
  software-properties-common \ 
  python-software-properties \
  && add-apt-repository ppa:pypa/ppa \
  && apt update \
  && apt install -y \
  pipenv \
  nodejs \
  snapd \
  yarn

ENV DEBIAN_FRONTEND=dialog
ENV USERNAME=$USERNAME
ENV USER_UID=$USER_UID
ENV USER_GID=$USER_GID
