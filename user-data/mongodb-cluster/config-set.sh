#!/bin/bash

function raise_command_not_found() {
    local cmd="$1"

   if ! command -v $cmd &> /dev/null {
        echo "$cmd is required"
        exit 1
    }
}

function install_docker() {
    curl https://get.docker.com | bash

    raise_command_not_found "docker"
}

function generate_init_cluster_script() {
    
}

function setup() {
    raise_command_not_found "curl"

    local public_ip=$(curl ipinfo.io/ip)

    docker run -d 
    --name configrepl1 \ 
    -v ~/shard/configsrv-node1:/root/shard/configsrv-node1 \ 
    -e MONGO_INITDB_ROOT_USERNAME=admin \
    -e MONGO_INITDB_ROOT_PASSWORD=admin \ 
    -p 28041:28041 mongo mongod \
    --configsvr \
    --port 28041\
    --bind_ip $public_ip\
    --replSet config_repl\
    --dbpath /root/shard/configsrv-node1 &
}

install_docker
setup