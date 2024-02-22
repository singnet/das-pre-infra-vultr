#!/bin/bash
set -e

USER_NAME="dasadmin"
MONGO_VERSION="7.0.5"
MONGO_PORT="28100"

function user_setup() {
   adduser --disabled-password --gecos "" "$USER_NAME"
   usermod -a -G $USER_NAME $USER_NAME
}

function docker_setup() {
   apt-get -y update
   apt-get -y install net-tools ca-certificates curl gnupg

   if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg
      echo \
         "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" |
         tee /etc/apt/sources.list.d/docker.list >/dev/null
   fi

   apt-get -y update
   apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   dockerd > /dev/null 2>&1 < /dev/null &
   docker run hello-world
   docker rm $(docker ps -a | grep hello | cut -d" " -f1)
   docker rmi hello-world
}

function mongo_setup() {
   docker image pull mongo:$MONGO_VERSION

   docker run --name mongo --restart always -p ${MONGO_PORT}:27017 -d mongo:$MONGO_VERSION
}

user_setup
docker_setup
mongo_setup
