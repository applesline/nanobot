#!/bin/bash

set -e

cd ~
mkdir -p ./.nanobot ./workspace

chown -R 1000:1000 ./.nanobot ./workspace
chmod 700 ./nanobot ./workspace

if [ ! -f ./.nanobot/config.json ]; then
    echo "$(pwd)/.nanobot/config.json file not exist!"
    return
fi

cd ~/nanobot

echo "Build docker image with name nanobot"
docker build -t nanobot .

echo "Start nanobot container..."

docker run -d  --name nanobot --user 1000:1000  --read-only --tmpfs /tmp:size=64m --cap-drop ALL  --security-opt no-new-privileges:true  -v ~/.nanobot:/home/nanobot/.nanobot:rw  nanobot  gateway
