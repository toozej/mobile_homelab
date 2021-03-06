#!/bin/bash

for PROJECT in $(find . -mindepth 1 -maxdepth 1 -type d -not -path '*/\.*'); do
    cd ${PROJECT}
    docker-compose down --remove-orphans
    cd -
done
