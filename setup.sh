#!/bin/bash

DOCKER_BIN=`which docker`
DOCKER_COMPOSE_BIN=`which docker-compose`
OPENSSL_BIN=`which openssl`

DOCKER_DIR=~/docker
MOBILE_HOMELAB_DIR=~/docker/mobile_homelab

echo "setting up mobile_homelab"

if [ ! -d "$DOCKER_DIR" ]; then
    echo "making $DOCKER_DIR"
    mkdir $DOCKER_DIR
else
    echo "$DOCKER_DIR already exists, skipping."
fi

if [ ! -d "$MOBILE_HOMELAB_DIR" ]; then
    echo "cloning down mobile_homelab from Github"
    git clone https://github.com/toozej/mobile_homelab.git $MOBILE_HOMELAB_DIR
else
    echo "mobile_homelab already exists at $MOBILE_HOMELAB_DIR, pulling"
    cd $MOBILE_HOMELAB_DIR
    git pull
fi

HOSTFILE_ENTRY_TRAEFIK=`grep traefik.test /etc/hosts`
HOSTFILE_ENTRY_JENKINS=`grep jenkins.test /etc/hosts`
if [ -z "$HOSTFILE_ENTRY_TRAEFIK" ] || [ -z "$HOSTFILE_ENTRY_JENKINS" ]; then
    echo "including hostfile entries"
    echo "127.0.0.1 traefik.test" | sudo tee -a /etc/hosts
    echo "127.0.0.1 jenkins.test" | sudo tee -a /etc/hosts
else
    echo "hostfile entries for traefik.test and jenkins.test already exist, skipping"
fi

if [ ! -f "$MOBILE_HOMELAB_DIR/traefik/traefik.key" ] || [ ! -f "$MOBILE_HOMELAB_DIR/traefik/traefik.crt" ]; then
    echo "generating openssl key & crt for Traefik"
    cd $MOBILE_HOMELAB_DIR/traefik
    $OPENSSL_BIN req -newkey rsa:2048 -nodes -keyout traefik.key -x509 -days 9999 -out traefik.crt
else
    echo "traefik.key and traefik.crt already exist, skipping."
fi

TRAEFIK_NETWORK_OUTPUT=`sudo docker network ls | awk '{print $2}' | grep --color=none traefik`
if [ "$TRAEFIK_NETWORK_OUTPUT" != "traefik" ]; then
    echo "setting up traefik network"
    sudo $DOCKER_BIN network create traefik
else
    echo "traefik network already exists, skipping."
fi

for PROJECT in `find $MOBILE_HOMELAB_DIR -mindepth 1 -maxdepth 1 -type d -not -path '*/\.*'`; do
    if [ ! -f "$PROJECT/.do_not_autorun" ]; then
        echo "starting docker-compose project in $PROJECT"
        sudo $DOCKER_COMPOSE_BIN -f $PROJECT/docker-compose.yml up --build -d
    else
        echo "$PROJECT set to not auto-run, remove $PROJECT/.do_not_autorun if you want to change this."
    fi
done
