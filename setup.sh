#!/bin/bash
# binaries to be used
DOCKER_BIN=$(command -v docker)
OPENSSL_BIN=$(command -v openssl)
CERTUTIL_BIN=$(command -v certutil)

# paths to be used
DOCKER_DIR="${HOME}"/docker
MOBILE_HOMELAB_DIR="${HOME}"/docker/mobile_homelab

MINIMAL=false

# help/usage information
function usage {
    echo "Usage: ./setup.sh [--minimal | -m] [--help | -h] "
    echo ""
    echo "  --minimal | -m          Run minimal mobile_homelab, just Traefik container."
    echo ""
    echo "  -h | --help                        Display usage."
}

# get user input
while :; do
  case $1 in
    -h | --help)
      usage
      exit 1
      ;;
    -m | --minimal)
      MINIMAL=true
      ;;
    ?)
      usage
      exit 1
      ;;
    *) break
  esac
  shift
done

echo "setting up mobile_homelab"


# ensure docker and mobile_homelab dirs exist
if [ ! -d "${DOCKER_DIR}" ]; then
    echo "making ${DOCKER_DIR}"
    mkdir "${DOCKER_DIR}"
else
    echo "${DOCKER_DIR} already exists, skipping."
fi


# clone repo from github
if [ ! -d "${MOBILE_HOMELAB_DIR}" ]; then
    echo "cloning down mobile_homelab from Github"
    git clone https://github.com/toozej/mobile_homelab.git "${MOBILE_HOMELAB_DIR}"
else
    echo "mobile_homelab already exists at ${MOBILE_HOMELAB_DIR}, pulling"
    cd "${MOBILE_HOMELAB_DIR}" || exit
    git pull
fi


# setup hostfile entries for projects
echo "setting up hostfile entries for mobile_homelab projects"
cd "${MOBILE_HOMELAB_DIR}" || exit
for PROJECT in $(find . -mindepth 1 -maxdepth 1 -type d -not -path '*/\.*'); do
    # remove prefix of "./"
    ENTRY=${PROJECT:2}
    # if there's not already a hostfile entry for $PROJECT, then add one
    if ! grep -q "${ENTRY}.lab.test" /etc/hosts; then
        echo "127.0.0.1 ${ENTRY}.lab.test" | sudo tee -a /etc/hosts
    fi
done


# setup SSL certificates
if [ ! -f "${MOBILE_HOMELAB_DIR}"/traefik/lab.test.key ] || [ ! -f "${MOBILE_HOMELAB_DIR}"/traefik/lab.test.crt ]; then
    echo "generating openssl key & crt for Traefik"
    cd "${MOBILE_HOMELAB_DIR}"/traefik || exit

    # setup files needed for generating certs below
    touch index.txt
    echo "01" > serial

    # steps largely borrowed from https://gist.github.com/Soarez/9688998
    # generate lab.test key
    "${OPENSSL_BIN}" genrsa -out lab.test.key 2048
    # verify lab.test key
    "${OPENSSL_BIN}" rsa -in lab.test.key -noout -text

    # generate CSR for lab.test with SANs
    "${OPENSSL_BIN}" req -new -out lab.test.csr -config lab.test.conf
    # verify lab.test CSR
    "${OPENSSL_BIN}" req -in lab.test.csr -noout -text
    
    # generate root CA key
    "${OPENSSL_BIN}" genrsa -out ca.key 2048
    # generate root CA cert
    "${OPENSSL_BIN}" req -new -x509 -key ca.key -out ca.crt -subj "/C=US/ST=Oregon/L=Portland/O=mobile_homelab/CN=[]"

    # sign and create lab.test.crt
    "${OPENSSL_BIN}" ca -batch -config ca.conf -out lab.test.crt -extfile lab.test.extensions.conf -in lab.test.csr
    
    # verify lab.test.crt
    "${OPENSSL_BIN}" x509 -in lab.test.crt -noout -text
    "${OPENSSL_BIN}" verify -CAfile ca.crt lab.test.crt

    # create bundle for browser
    cat lab.test.crt ca.crt > lab.test.bundle.crt
else
    echo "lab.test.key and lab.test.crt already exist, skipping."
fi


# trust the newly created certificates in web browser
echo "trusting self-signed certificates and adding to browser storage"
[ -d "${HOME}"/.pki/nssdb ] || mkdir -p "${HOME}"/.pki/nssdb
# import ca certificate to browser storage
"${CERTUTIL_BIN}" -d sql:"${HOME}"/.pki/nssdb -A -n 'lab.test certificate authority' -i "${MOBILE_HOMELAB_DIR}"/traefik/ca.crt -t TCP,TCP,TCP

# if there's already a cert in storage matching our *.lab.test cert, remove it as it must be old
CERTUTIL_LOADED_CERTS=$("${CERTUTIL_BIN}" -d sql:"${HOME}"/.pki/nssdb -L)
if [[ "${CERTUTIL_LOADED_CERTS}" == *"*.lab.test certificate authority"* ]]; then
    "${CERTUTIL_BIN}" -d sql:"${HOME}"/.pki/nssdb -D -n "*.lab.test certificate authority"
fi

# import *.lab.test certificate to browser storage
"${CERTUTIL_BIN}" -d sql:"${HOME}"/.pki/nssdb -A -n '*.lab.test wildcard certificate' -i "${MOBILE_HOMELAB_DIR}"/traefik/lab.test.bundle.crt -t TCP,TCP,TCP


# create the Traefik network if not already created
TRAEFIK_NETWORK_OUTPUT=$(docker network ls | awk '{print $2}' | grep --color=none traefik)
if [ "${TRAEFIK_NETWORK_OUTPUT}" != "traefik" ]; then
    echo "setting up traefik network"
    "${DOCKER_BIN}" network create traefik
else
    echo "traefik network already exists, skipping."
fi

# create the tick network if not already created
TICK_NETWORK_OUTPUT=$(docker network ls | awk '{print $2}' | grep --color=none tick)
if [ "${TICK_NETWORK_OUTPUT}" != "tick" ]; then
    echo "setting up tick network"
    "${DOCKER_BIN}" network create tick
else
    echo "tick network already exists, skipping."
fi


# pull images, build and start up projects
if [[ ${MINIMAL} == "false" ]]; then
    for PROJECT in $(find "${MOBILE_HOMELAB_DIR}" -mindepth 1 -maxdepth 1 -type d -not -path '*/\.*'); do
        if [ ! -f "${PROJECT}/.do_not_autorun" ]; then
            echo "starting docker-compose project in ${PROJECT}"
            /usr/bin/docker compose -f "${PROJECT}/docker-compose.yml" pull --ignore-pull-failures
            /usr/bin/docker compose -f "${PROJECT}/docker-compose.yml" up --build -d
        else
            echo "${PROJECT} set to not auto-run, remove ${PROJECT}/.do_not_autorun if you want to change this."
        fi
    done
    
    # wait for projects to finish starting, and show Jenkins initial password
    echo "sleeping 60 seconds to allow projects to fully spin up" && sleep 60
    JENKINS_PASSWORD=$(sudo cat "${MOBILE_HOMELAB_DIR}"/jenkins/jenkins_home/secrets/initialAdminPassword)
    echo "Jenkins initial admin password is: ${JENKINS_PASSWORD}"
else
    echo "minimal mode activated"
    PROJECT="traefik"
    echo "starting docker-compose project in ${PROJECT}"
    /usr/bin/docker compose -f "${PROJECT}/docker-compose.yml" pull --ignore-pull-failures
    /usr/bin/docker compose -f "${PROJECT}/docker-compose.yml" up --build -d
fi
