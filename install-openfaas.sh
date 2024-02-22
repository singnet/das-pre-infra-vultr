#!/bin/bash
set -e

USER_NAME="dasadmin"

function user_setup() {
    adduser --disabled-password --gecos "" "$USER_NAME"
    usermod -a -G $USER_NAME $USER_NAME
}

function openfaas_setup() {
    cat <<EOF >install-openfaas.sh
#!/bin/bash
set -ex
git clone https://github.com/openfaas/faasd --depth=1
cd faasd
./hack/install.sh
mkdir -p /var/lib/faasd/.docker/
EOF

    chmod +x install-openfaas.sh
    ./install-openfaas.sh >>install-openfaas.log 2>&1
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

function firewall_setup() {
    if ! command -v ufw &>/dev/null; then
        apt-get update
        apt-get install ufw
    fi

    ufw -y enable
    ufw allow 8080/tcp
    ufw allow ssh
}

user_setup
docker_setup
openfaas_setup
firewall_setup
