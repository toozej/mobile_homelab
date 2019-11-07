# Mobile Homelab

A quick little wrapper around a few basic docker-compose projects to fire up a mobile homelab for on-the-go development and testing. 
It aims to be easy to setup with an automated installation process, and easy to trash `rm -rf $MOBILE_HOMELAB_DIR` and rebuild.

## Pre-reqs

1. docker and docker-compose installed (`which docker` and `which docker-compose` return something valid)
2. openssl command-line tools installed (`which openssl` returns something valid)

## Automated first time setup

1. `wget https://raw.githubusercontent.com/toozej/mobile_homelab/master/setup.sh && chmod +x setup.sh`
2. `./setup.sh`

## Features provided

1. [Traefik][traefik] for automatic reverse proxying and SSL termination
2. [NGINX][nginx] for a quick and basic web server
3. [Jenkins X][jenkins] for building packages, CI/CD, etc.
4. [Portainer][portainer] to provide a quick way to provision other tools and services

[traefik]: https://hub.docker.com/_/traefik
[nginx]: https://hub.docker.com/_/nginx
[jenkins]: https://hub.docker.com/_/jenkins
[portainer]: https://hub.docker.com/portainer/portainer
