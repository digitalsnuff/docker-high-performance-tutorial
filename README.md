# Docker High Performance

Public Key Infrastructure (PKI).
Certificate Authority (CA)

```sh
# SERVER
#
# generate a private key
openssl genrsa -out /etc/docker/server-key.pem 2048
#  generate a Certificate Signing Request (CSR)
openssl req -key /etc/docker/server-key.pem -new -subj "/CN=dockerhost" -sha256 -out dockerhost.csr

# reconfigure the Docker Engine daemon file, /etc/docker/daemon.json, to use those certificates:
# {
#   "tlsverify": true,
#   "tlscacert": "/etc/docker/ca.pem",
#   "tlskey": "/etc/docker/server-key.pem",
#   "tlscert": "/etc/docker/server.pem"
# }

# configure the Docker Engine daemon to listen to a secure port by creating a systemd override file

cat <<EOL | tee -a /etc/systemd/system/docker.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H unix:// -H tcp://0.0.0.0:2377
EOL

#  restart Docker Engine
systemctl daemon-reload
systemctl restart docker.service

# END SERVER
#
# CLIENT
# generate CA private key
mkdir ./ca
cd ca
openssl genrsa -aes256 -out ca-key.pem 4096
chmod 600 ca-key.pem
ls -l ca-key.pem
# generate a certificate for our CA that is self-signed
openssl req -key ca-key.pem -new -x509 \
-subj '/CN=Certificate Authority' \
-sha256 -days 365 -out ca.pem
cat ca.pem
#
# Generate keys on server
#
# Download dockerhost.csr from server
# prepare an OpenSSL configuration server-ext.cnf with `extendedKeyUsage = serverAuth`
# sign the CSR with our CA
cd ./ca
touch server-ext.cnf
openssl x509 -req -CA ca.pem -CAkey ca-key.pem \
-CAcreateserial -extfile server-ext.cnf \
-in ds-dev.csr -out ds-dev.pem
# copy the certificates of our Docker host and CA from our client workstation
cp ./ca/ca.pem /etc/docker/ca.pem
cd ./ca/dockerhost.pem /etc/docker/server.pem

# END CLIENT
```

## Connecting

```sh
# generate the private key
openssl genrsa -out ~/.docker/key.pem 4096
#  generate the CSR for client in a file
openssl req -subj '/CN=client' -new -key ~/.docker/key.pem -out client.csr
# Create OpenSSL configuration
cd ./ca
touch client-ext.cnf
echo 'extendedKeyUsage = clientAuth' | tee -a client-ext.cnf
#  issue the certificate for our Docker client
openssl x509 -req -CA ca.pem -CAkey ca-key.pem -CAcreateserial -extfile client-ext.cnf -in ~/client.csr -out ~/.docker/cert.pem
cp ca.pem ~/.docker/ca.pem
# exporting the following environment variables
export DOCKER_HOST=tcp://dockerhost:2376
export DOCKER_TLS_VERIFY=true
```

## Requirements

```sh
# Install VirtualBox Guest
vagrant plugin install vagrant-vbguest
vagrant reload
```

## Building a Docker Swarm cluster

```sh
# run for mastr
docker swarm init --advertise-addr=192.168.0.0 --listen-addr=192.168.0.0
docker node ls
```

# Chef

The concept of configuration management of Docker hosts.

The Docker Engine has several parameters to tune, such as cgroups, memory, CPU, filesystems, networking, and so on.
Configuration management is a strategy to manage the changes happening in all aspects of
our application, and it reports and audits the changes made to our system.

Chef is a configuration management tool that provides a domain-specific language to
model the configuration of our infrastructure. Each configuration item in our infrastructure
is modeled as a resource.

A cookbook is a fundamental unit of distributing configuration and policy to our servers.

A Chef environment consists of three things:

- A Chef server
- A workstation
- A node

The Chef server is the central repository of cookbooks and other policy items governing our
entire infrastructure. It contains metadata about the infrastructure that we are managing.

The workstation is used to
interact with the Chef server. This is where we will do most of the preparation work and
create the code to send to the Chef server.

Another important component in our workstation is the Chef Development Kit. It contains
all the programs needed to read all the configuration in our chef-repo and interact with
the Chef server. Convenient programs to create, develop, and test our cookbooks are also
available in the Chef Development Kit.

A node is any computer that is
managed by Chef. It can be a physical machine, a virtual machine, a server in the cloud, or
a networking device.

When a chef-client is run on our node, it performs the following steps:

1. It registers and authenticates the node with the Chef server
2. It gathers system information in our node to create a node object
3. Then, it synchronizes the Chef cookbooks needed by our node
4. It compiles the resources by loading our node's needed recipes
5. Next, it executes all the resources and performs the corresponding actions to configure our node
6. Finally, it reports the result of the chef-client run back to the Chef server and other configured notification endpoints

[Link to Chef documentation](https://docs.chef.io/)
[Chef account](https://manage.chef.io/signup)
[Chef Development Kit](https://downloads.chef.io/products/chefdk)

# Source

Allan Espinosa, Russ McKendrick, _Docker High Performance. Second Edition_, ISBN 978-1-78980-721-9, Packt Publishing 2019
