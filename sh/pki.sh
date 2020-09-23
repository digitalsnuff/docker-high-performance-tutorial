#!/bin/bash

PKI_PATH="../pki/"
[ -d "${PKI_PATH}" ] && echo "Directory $PKI_PATH already exists." || (echo "Directory $PKI_PATH not found. Making folder..." && mkdir $PKI_PATH && echo "Success!")
rm -rf ${PKI_PATH}*

pushd $PKI_PATH

mkdir -p ./client/ca/ && cd ./client/ca/
# create CA (Certificate Authority)
CLIENT_CA_KEY_FILE="ca-key.pem"
CLIENT_CA_CERT_FILE="ca.pem"
openssl genrsa -aes256 -out ${CLIENT_CA_KEY_FILE} 4096
chmod 644 ${CLIENT_CA_KEY_FILE}
ls -l ${CLIENT_CA_KEY_FILE}
# generate a certificate for our CA that is self-signed
openssl req -key ${CLIENT_CA_KEY_FILE} -new -x509 -subj '/CN=Certificate Authority' -sha256 -days 365 -out ${CLIENT_CA_CERT_FILE}
cat ${CLIENT_CA_CERT_FILE}
# create cnf
echo "extendedKeyUsage = serverAuth" | tee -a ../server-ext.cnf
cd -

# Enabling remote access
# generate private key for ferver
SERVER_MASTER_01_NAME="docker-swarm-master-01"
mkdir -p ./server/${SERVER_MASTER_01_NAME}/ && cd ./server/${SERVER_MASTER_01_NAME}/
SERVER_PRIVATE_KEY_FILE="server-key.pem"
SERVER_CSR_FILE="${SERVER_MASTER_01_NAME}.csr"
# Generate key for /etc/docker/
openssl genrsa -out ${SERVER_PRIVATE_KEY_FILE} 4096
chmod 600 ${SERVER_PRIVATE_KEY_FILE}
ls -l ${SERVER_PRIVATE_KEY_FILE}
# Use this file to generate a Certificate Signing Request (CSR)
openssl req -key ${SERVER_PRIVATE_KEY_FILE} -new -subj "/CN=${SERVER_MASTER_01_NAME}" -sha256 -out ${SERVER_CSR_FILE}
ls -l ${SERVER_CSR_FILE}
# copy CSR to client
cp ${SERVER_CSR_FILE} ../../client/${SERVER_CSR_FILE}
# copy CA to server
cp ../../client/ca/${CLIENT_CA_CERT_FILE} ./${CLIENT_CA_CERT_FILE}
# Configuration for /etc/docker/daemon.json
cat << EOF | tee -a daemon.json
{
  "debug": true,
  "tls": true,
  "tlsverify": true,
  "tlscert": "/var/docker/server.pem",
  "tlscacert": "/etc/docker/ca.pem",
  "tlskey": "/etc/docker/server-key.pem",
  "hosts": ["tcp://0.0.0.0:2377"]
}
EOF

cd -
#
#  sign the CSR with our CA for client
cd ./client/
openssl x509 -req -CA ./ca/${CLIENT_CA_CERT_FILE} -CAkey ./ca/${CLIENT_CA_KEY_FILE} \
-CAcreateserial -extfile server-ext.cnf \
-in ${SERVER_CSR_FILE} -out ${SERVER_MASTER_01_NAME}.pem
# copy pem to server (for  /etc/docker/)
cp ${SERVER_MASTER_01_NAME}.pem ../server/${SERVER_MASTER_01_NAME}/${SERVER_MASTER_01_NAME}.pem
# generate key for Docker client

mkdir docker
openssl genrsa -out ./docker/key.pem 4096
# generate the CSR for client in a file called client.csr
openssl req -subj '/CN=client' -new -key ./docker/key.pem -out ds-dev.csr
#  The OpenSSL command following creates this configuration in a file called ~/ca/client-ext.cnf
cat << EOL | tee -a client-ext.cnf
extendedKeyUsage = clientAuth
EOL
# generate cert
openssl x509 -req -CA ./ca/${CLIENT_CA_CERT_FILE} -CAkey ./ca/${CLIENT_CA_KEY_FILE} -CAcreateserial \
-extfile client-ext.cnf \
-in client.csr -out ./docker/cert.pem

cp ./docker/key.pem ~/.docker/key.pem
cp ./docker/cert.pem ~/.docker/cert.pem
cp ./ca/${CLIENT_CA_CERT_FILE} ~/.docker/ca.pem

cd -

popd

export DOCKER_HOST=tcp://${SERVER_MASTER_01_NAME}:2376
export DOCKER_TLS_VERIFY=true

echo 'FINISH!!!'