#!/bin/bash
# binaries to be used
DOCKER_BIN=`which docker`
DOCKER_COMPOSE_BIN=`which docker-compose`
OPENSSL_BIN=`which openssl`
CERTUTIL_BIN=`which certutil`

# paths to be used
DOCKER_DIR=~/docker
MOBILE_HOMELAB_DIR=~/docker/mobile_homelab

echo "setting up mobile_homelab"


# ensure docker and mobile_homelab dirs exist
if [ ! -d "$DOCKER_DIR" ]; then
    echo "making $DOCKER_DIR"
    mkdir $DOCKER_DIR
else
    echo "$DOCKER_DIR already exists, skipping."
fi


# clone repo from github
if [ ! -d "$MOBILE_HOMELAB_DIR" ]; then
    echo "cloning down mobile_homelab from Github"
    git clone https://github.com/toozej/mobile_homelab.git $MOBILE_HOMELAB_DIR
else
    echo "mobile_homelab already exists at $MOBILE_HOMELAB_DIR, pulling"
    cd $MOBILE_HOMELAB_DIR
    git pull
fi


# setup hostfile entries for projects
echo "setting up hostfile entries for mobile_homelab projects"
cd $MOBILE_HOMELAB_DIR
for PROJECT in `find . -mindepth 1 -maxdepth 1 -type d -not -path '*/\.*'`; do
    # remove prefix of "./"
    ENTRY=${PROJECT:2}
    # if there's not already a hostfile entry for $PROJECT, then add one
    if ! grep -q "$ENTRY.lab.test" /etc/hosts; then
        echo "127.0.0.1 $ENTRY.lab.test" | sudo tee -a /etc/hosts
    fi
done


# setup SSL certificates
if [ ! -f "$MOBILE_HOMELAB_DIR/traefik/lab.test.key" ] || [ ! -f "$MOBILE_HOMELAB_DIR/traefik/lab.test.crt" ]; then
    echo "generating openssl key & crt for Traefik"
    cd $MOBILE_HOMELAB_DIR/traefik

    # steps largely borrowed from https://gist.github.com/Soarez/9688998
    # generate lab.test key
    $OPENSSL_BIN genrsa -out lab.test.key 2048
    # verify lab.test key
    $OPENSSL_BIN rsa -in lab.test.key -noout -text

    # generate CSR for lab.test with SANs
    $OPENSSL_BIN req -new -out lab.test.csr -config lab.test.conf
    # verify lab.test CSR
    $OPENSSL_BIN req -in lab.test.csr -noout -text
    
    # generate root CA key
    $OPENSSL_BIN genrsa -out ca.key 2048
    # generate root CA cert
    $OPENSSL_BIN req -new -x509 -key ca.key -out ca.crt -subj "/C=US/ST=Oregon/L=Portland/O=mobile_homelab/CN=[]"

    # sign and create lab.test.crt
    $OPENSSL_BIN ca -batch -config ca.conf -out lab.test.crt -extfile lab.test.extensions.conf -in lab.test.csr
    
    # verify lab.test.crt
    $OPENSSL_BIN x509 -in lab.test.crt -noout -text
    $OPENSSL_BIN verify -CAfile ca.crt lab.test.crt

    # create bundle for browser
    cat lab.test.crt ca.crt > lab.test.bundle.crt
else
    echo "lab.test.key and lab.test.crt already exist, skipping."
fi


# trust the newly created certificates in web browser
echo "trusting self-signed certificates and adding to browser storage"
[ -d ~/.pki/nssdb ] || mkdir -p ~/.pki/nssdb
# import ca certificate to browser storage
$CERTUTIL_BIN -d sql:$HOME/.pki/nssdb -A -n 'lab.test certificate authority' -i $MOBILE_HOMELAB_DIR/traefik/ca.crt -t TCP,TCP,TCP

# if there's already a cert in storage matching our *.lab.test cert, remove it as it must be old
CERTUTIL_LOADED_CERTS=`$CERTUTIL_BIN -d sql:$HOME/.pki/nssdb -L`
if [[ $CERTUTIL_LOADED_CERTS == *"*.lab.test certificate authority"* ]]; then
    $CERTUTIL_BIN -d sql:$HOME/.pki/nssdb -D -n "*.lab.test certificate authority"
fi

# import *.lab.test certificate to browser storage
$CERTUTIL_BIN -d sql:$HOME/.pki/nssdb -A -n '*.lab.test wildcard certificate' -i $MOBILE_HOMELAB_DIR/traefik/lab.test.bundle.crt -t TCP,TCP,TCP


# create the Traefik network if not already created
TRAEFIK_NETWORK_OUTPUT=`sudo docker network ls | awk '{print $2}' | grep --color=none traefik`
if [ "$TRAEFIK_NETWORK_OUTPUT" != "traefik" ]; then
    echo "setting up traefik network"
    sudo $DOCKER_BIN network create traefik
else
    echo "traefik network already exists, skipping."
fi


# pull images, build and start up projects
for PROJECT in `find $MOBILE_HOMELAB_DIR -mindepth 1 -maxdepth 1 -type d -not -path '*/\.*'`; do
    if [ ! -f "$PROJECT/.do_not_autorun" ]; then
        echo "starting docker-compose project in $PROJECT"
        sudo $DOCKER_COMPOSE_BIN -f $PROJECT/docker-compose.yml pull --ignore-pull-failures
        sudo $DOCKER_COMPOSE_BIN -f $PROJECT/docker-compose.yml up --build -d
    else
        echo "$PROJECT set to not auto-run, remove $PROJECT/.do_not_autorun if you want to change this."
    fi
done


# wait for projects to finish starting, and show Jenkins initial password
echo "sleeping 30 seconds to allow projects to fully spin up" && sleep 30
JENKINS_PASSWORD=`sudo cat $MOBILE_HOMELAB_DIR/jenkins/jenkins_home/secrets/initialAdminPassword`
echo "Jenkins initial admin password is: $JENKINS_PASSWORD"
