# Mobile Homelab

A quick little wrapper around two basic docker-compose projects to fire up a mobile homelab for on-the-go development and testing. 
It aims to be easy to setup with an automated installation process, and easy to trash `rm -rf $MOBILE_HOMELAB_DIR` and rebuild.

## Pre-reqs

1. docker and docker-compose installed (`which docker` and `which docker-compose` return something valid)
2. openssl command-line tools installed (`which openssl` returns something valid)

## Automated first time setup

1. `wget https://raw.githubusercontent.com/toozej/mobile_homelab/master/setup.sh && chmod +x setup.sh`
2. `./setup.sh`


## Manual first time setup

1. download repo: `git clone https://github.com/toozej/mobile_homelab.git`
2. setup traefik network with: `docker network create traefik`
3. move into the traefik directory `cd ./mobile_homelab/traefik/`
4. generate SSL key for traefik: `openssl req -newkey rsa:2048 -nodes -keyout traefik.key -x509 -days 9999 -out traefik.crt`
5. include hostfile entry for traefik: `echo "127.0.0.1 traefik.dev" | sudo tee -a /etc/hosts`
6. include hostfile entry for jenkins: `echo "127.0.0.1 jenkins.dev" | sudo tee -a /etc/hosts`
7. start traefik: `docker-compose up -d`
8. start jenkins: `cd ../jenkins/ && docker-compose up --build -d`
