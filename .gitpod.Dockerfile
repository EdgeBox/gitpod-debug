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


