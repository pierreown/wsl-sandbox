#!/bin/sh

cd "$(dirname "$0")" || exit

BASE_URL="https://purge.jsdelivr.net/gh/pierreown/sandbox-script@main"
for SCRIPT in *.sh; do
    curl -L "${BASE_URL}/${SCRIPT}"
done
