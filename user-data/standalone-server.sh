#!/bin/bash

set -e

function required_variable() {
    if [ -z "$1" ]; then
        echo "The variable is not defined."
        exit 1
    fi
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

function user_setup() {
    required_variable ${user_name}

    user_exists=$(getent passwd ${user_name})

    if [ -z $user_exists ]; then
        adduser --disabled-password --gecos "" "${user_name}"
        usermod -a -G "${user_name}" "${user_name}"
    else
        echo "Skipping: user ${user_name} already exists"
    fi
}

function firewall_setup() {
    if ! command -v ufw &>/dev/null; then
        apt-get update
        apt-get install ufw
    fi

    ufw enable
    ufw allow ssh
}

function install_toolbox() {
    if ! command -v das-cli &>/dev/null; then
        bash -c "wget -O - http://45.77.4.33/apt-repo/setup.sh | bash"

        apt install das-cli
    else
        echo "Skipping setup installation, because das-cli is already installed."
    fi
}

function toolbox_setup() {
    required_variable "${mongo_port}"
    required_variable "${redis_port}"
    required_variable "${redis_node_len}"

    install_toolbox

    ufw allow ${redis_port}/tcp
    ufw allow ${mongo_port}/tcp
    ufw allow 8080/tcp

    if [ ${redis_node_len} -gt 0 ]; then
        redis_cluster="yes"
    else
        redis_cluster="no"
    fi

    read -ra redis_nodes <<<"${redis_nodes}"

    {
        echo "${redis_port}"
        echo "$redis_cluster"
        if [ "$redis_cluster" == "yes" ]; then
            count=0
            for ip in "$${redis_nodes[@]}"; do
                echo "$ip"
                echo
                count=$((count + 1))
                if [ $count -ge 2 ]; then
                    if [ $count -eq ${redis_node_len} ]; then
                        echo "no"
                    else
                        echo "yes"
                    fi
                fi
            done
        fi
        echo "${mongo_port}"
        echo "admin"
        echo "admin"
        echo "8888"
    } >/tmp/toolbox_config.txt

    das-cli config set </tmp/toolbox_config.txt
}

function main() {
    required_variable "${environment_type}"

    local LOG_FILE="/tmp/install.log"

    exec >"$LOG_FILE" 2>&1

    #user_setup
    docker_setup
    firewall_setup
    install_toolbox
    toolbox_setup
}

main
