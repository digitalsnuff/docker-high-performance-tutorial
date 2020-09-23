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
ExecStart=/usr/bin/dockerd -H unix:// -H tcp://0.0.0.0:2376
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
vagrant plugin install vagrant-dotenv
vagrant reload
```

## Building a Docker Swarm cluster

```sh
# run for mastr
docker swarm init --advertise-addr=192.168.0.0 --listen-addr=192.168.0.0
docker node ls
```

# Source

Allan Espinosa, Russ McKendrick, _Docker High Performance. Second Edition_, ISBN 978-1-78980-721-9, Packt Publishing 2019
