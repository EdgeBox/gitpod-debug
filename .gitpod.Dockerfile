FROM gitpod/workspace-full

USER gitpod

RUN sudo apt-get -q update && \
    sudo apt-get install -y awscli && \
    sudo rm -rf /var/lib/apt/lists/*

COPY scripts/.bash_aliases $HOME

ENV AWS_DEFAULT_REGION=eu-central-1

# Switch to the root user for package installation
USER root

# Update Linux packages
RUN ["apt-get", "update"]

# Install cron
RUN sudo apt-get install -y cron
COPY scripts/sync-core-crontab /etc/cron.d/
RUN sudo chmod 0644 /etc/cron.d/sync-core-crontab &&\
    sudo crontab /etc/cron.d/sync-core-crontab

# Install OpenShift CLI
RUN wget https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz &&\
    tar xvfz openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz &&\
    sudo chmod a+x openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit/oc &&\
    sudo mv openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit/oc /usr/local/bin/

# Install z shell
RUN ["apt-get", "install", "-y", "zsh"]

# Set zsh as default Shell
RUN ["sed", "s/required/sufficient/g", "-i", "/etc/pam.d/chsh"]

# Switch to the Gitpod user
USER gitpod

# Install the z shell framework Oh My Zsh
RUN sh -c "$(wget -qO- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Ghost inspector so we can run automated end-to-end tests against our environment.
RUN npm install -g ghost-inspector

# Set zsh as default Shell
# RUN ["chsh", "-s", "$(which zsh)"]
# ENV SHELL=zsh

# Append the nvm loading script to the end of ~/.zshrc
# This is what allows you to run 'nvm' commands with z shell
# RUN printf 'export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"\n [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.zshrc
