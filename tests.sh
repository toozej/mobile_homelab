#!/bin/bash

set -xe 

# curl compose projects to ensure they're actually running
curl -s -k -L --user traefik:traefik https://traefik.lab.test | grep "Traefik UI"
curl -s -k -L https://jenkins.lab.test | grep "Authentication required"
curl -s -k -L https://www.lab.test | grep "Welcome"
curl -s -k -L https://portainer.lab.test | grep "Portainer"
curl -s -k -L https://tick.lab.test | grep "Chronograf"
echo "if we got to this point the test has finished successfully, exiting."
