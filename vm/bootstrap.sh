#!/bin/bash

dnf clean packages
sudo yum clean all
# sudo yum check-update
# sudo yum update -y

sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine

sudo yum install -y yum-utils
sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

sudo yum update -y
sudo yum install -y https://download.docker.com/linux/centos/8/x86_64/stable/Packages/containerd.io-1.3.7-3.1.el8.x86_64.rpm
sudo yum install docker-ce docker-ce-cli -y

sudo usermod -aG docker vagrant
newgrp docker 

# mkdir /home/vagrant/.docker
# chown vagrant:vagrant /home/vagrant/.docker -R
# chmod g+rwx /home/vagrant/.docker -R

# sudo mkdir -p /etc/systemd/system/docker.service.d

# Config for /etc/systemd/system/docker.service.d/override.conf
# Configuring remote access with systemd unit file
# cat << EOF | tee -a /etc/systemd/system/docker.service.d/override.conf
# [Service]
# ExecStart=
# ExecStart=/usr/bin/dockerd
# EOF

sudo systemctl enable docker.service
sudo systemctl start docker.service
sudo systemctl daemon-reload

# sudo yum remove docker-ce docker-ce-cli containerd.io
# sudo rm -rf /var/lib/docker