#!/bin/bash

# curl compose projects to ensure they're actually running
curl -s -k -L --user traefik:traefik https://traefik.lab.test | grep "Traefik UI" || exit 1
curl -s -k -L https://jenkins.lab.test | grep "Authentication required" || exit 1
curl -s -k -L https://www.lab.test | grep Welcome || exit 1
curl -s -k -L https://portainer.lab.test | grep Portainer || exit 1
curl -s -k -L https://tick.lab.test | grep Chronograf || exit 1
echo "if we got to this point the test has finished successfully, exiting." && exit 0
