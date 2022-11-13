#!/bin/bash

for PROJECT in $(find . -mindepth 1 -maxdepth 1 -type d -not -path '*/\.*'); do
    cd "${PROJECT}" || exit
    /usr/bin/docker compose down --remove-orphans
    cd - || exit
done
