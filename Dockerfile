FROM jenkins/jenkins:lts-jdk11

USER root
RUN apt-get update && \
    apt-get install -y curl docker.io awscli && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
USER jenkins
