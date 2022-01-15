#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Jeremy Combs. All rights reserved.
# Licensed under the MIT License.
#-------------------------------------------------------------------------------------------------------------

FROM ubuntu:latest
LABEL Maintainer = "Jeremy Combs <jmcombs@me.com>"

# Switching to non-interactive for cotainer build
ENV DEBIAN_FRONTEND=noninteractive

# Specify arguments for creation of non-root user in container (created after apt installs)
# Microsoft Article on non-root users in containers: 
#   https://aka.ms/vscode-remote/containers/non-root-user
# For VS Code Remote Cotaniners use the "remoteUser" property in devcontainer.json
#   to use non-root user
ARG USERNAME=coder
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Configure apt and install packages
RUN apt-get update \
    && apt-get -y install --no-install-recommends apt-utils dialog 2>&1 \ 
    #
    # Verify git and needed tools are installed
    && apt-get -y install \ 
        apt-transport-https \
        ca-certificates \
        git \
        gnupg \
        iproute2 \
        iputils-ping \
        locales \
        mkisofs \
        procps \
        python3-crcmod \
        python3-dev \
        python3-pip \
        python3-venv \
        software-properties-common \
        sudo \
        unzip \
        wget \
        zsh 

# Configure en_US.UTF-8 Locale
## apt-get package: locales
ENV LANGUAGE=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8
RUN localedef -c -i en_US -f UTF-8 en_US.UTF-8 \
    && locale-gen en_US.UTF-8 \
    && dpkg-reconfigure locales

# Set up User and grant sudo privileges 
# apt-get package: sudo
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID --shell /bin/zsh --create-home $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME
WORKDIR /home/$USERNAME

# Install & Configure OhMyZSH
# apt-get package: zsh
RUN wget https://github.com/ohmyzsh/ohmyzsh/raw/master/tools/install.sh -O - | zsh || true \
    && cp -R /root/.oh-my-zsh /home/$USERNAME \
    && cp /root/.zsh* /home/$USERNAME \
    && sed -i "s/\/root/\/home\/${USERNAME}/g" /home/"${USERNAME}"/.zshrc \
    && sed -i "s/ZSH_THEME=\"robbyrussell\"/ZSH_THEME=\"maran\"/g" /home/"${USERNAME}"/.zshrc

# Install Microsoft PowerShell via Package Repository - Ubuntu 20.04
# https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-7.1#installation-via-package-repository---ubuntu-2004
# apt-get package: wget, apt-transport-https, software-properties-common
    # Download the Microsoft repository GPG keys
RUN wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb \
    # Register the Microsoft repository GPG keys
    && sudo dpkg -i packages-microsoft-prod.deb \
    # Update the list of products
    && sudo apt-get update \
    # Enable the "universe" repositories
    && sudo add-apt-repository universe \
    # Install PowerShell
    && sudo apt-get install -y powershell \
    # Install .NET Core 3.1
    && sudo apt-get install -y dotnet-runtime-3.1 \
    # Remove Microsoft repository GPG keys
    && rm -f packages-microsoft-prod.deb

# Install PowerShell Modules
    # Az PowerShell Module
RUN pwsh -Command Install-Module -Name Az -Scope AllUsers -Repository PSGallery -Force -Verbose

# Set up Python3 Virtual Environments
RUN python3 -m venv py3-venv

# Determine system architecture & install architecutre dependent applications:
#   - ngrok
RUN ARCH=`uname -m` \
    && case "$ARCH" in \
        armhf) ARCH='arm' ;; \
        armv7) ARCH='arm' ;; \
        aarch64) ARCH='arm64' ;; \
        x86_64) ARCH='amd64' ;; \
        x86) ARCH='386' ;; \
        *) echo >&2 "error: unsupported architecture: $ARCH"; exit 1 ;; \
    esac && \
    # ngrok
    wget https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-${ARCH}.tgz --progress=bar \
    && tar -xvf ngrok-stable-linux-${ARCH}.tgz \
    && mv ngrok /usr/local/bin/ \
    && rm -f ngrok-stable-linux-${ARCH}.tgz

# Install NodeJS via nodesource
# https://github.com/nodesource/distributions/blob/master/README.md
# apt-get package: wget
ARG NODEVERSION=14
RUN wget https://deb.nodesource.com/setup_${NODEVERSION}.x -O - | sudo -E bash - \
    && sudo apt-get install -y nodejs

# Update NPM
 RUN npm install -g npm@latest

# Clean up
RUN apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Use non-root user as default account when launching container
USER $USERNAME

# Switching back to interactive after container build
ENV DEBIAN_FRONTEND=dialog
