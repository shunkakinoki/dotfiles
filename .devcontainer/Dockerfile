FROM mcr.microsoft.com/oryx/build:vso-20200417.5

RUN apt-get update -yq\
  && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -yq install --no-install-recommends apt-utils dialog 2>&1 \
  && apt-get install -yq \
  default-jdk \
  vim \
  sudo \
  xtail \
  fish \
  zsh \
  curl \
  gnupg \
  apt-transport-https \
  lsb-release \
  software-properties-common \
  unzip \
  && apt-get upgrade -yq git \
  && apt-get autoremove -y \
  && apt-get clean -y
