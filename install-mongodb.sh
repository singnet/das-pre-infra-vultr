#!/bin/bash
set -e

function required_variable() {
   if [ -z "${1}" ]; then
      echo "The variable is not defined."
      exit 1
   fi
}

function check_variables() {
   required_variable "${USER_NAME}"
   required_variable "${MONGO_VERSION}"
   required_variable "${OPENFAAS_INSTANCE_ID}"
   required_variable "${MONGO_PORT}"
}

function user_setup() {
   adduser --disabled-password --gecos "" "${USER_NAME}"
   usermod -a -G "${USER_NAME}" "${USER_NAME}"
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
   dockerd >/dev/null 2>&1 </dev/null &
   docker run hello-world
   docker rm $(docker ps -a | grep hello | cut -d" " -f1)
   docker rmi hello-world
}

function mongo_setup() {
   docker image pull "mongo:${MONGO_VERSION}"

   docker run --name mongo --restart always -p ${MONGO_PORT}:27017 -d "mongo:${MONGO_VERSION}"
}

function firewall_setup() {
   if ! command -v ufw &>/dev/null; then
      apt-get update
      apt-get install ufw
   fi

   ufw -y enable
   ufw allow from ${OPENFAAS_INSTANCE_ID} to any port ${MONGO_PORT} proto tcp
   ufw allow ssh
}

LOG_FILE="/tmp/install-mongodb.log"

exec >"$LOG_FILE" 2>&1

check_variables
user_setup
docker_setup
mongo_setup
firewall_setup
