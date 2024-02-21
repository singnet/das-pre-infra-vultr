#!/bin/bash
set -e

USER_NAME="dasadmin"

function user_setup() {
    adduser $USER_NAME
    usermod -a -G sudo $USER_NAME
    su $USER_NAME
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
    sudo apt-get update
    sudo apt install net-tools ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
        "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" |
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo docker run hello-world
    sudo docker rm $(sudo docker ps -a | grep hello | cut -d" " -f1)
    sudo docker rmi hello-world
    sudo usermod -a -G docker $USER_NAME
}

function firewall_setup() {
    if ! command -v ufw &>/dev/null; then
        sudo apt-get update
        sudo apt-get install ufw
    fi

    sudo ufw enable
    sudo ufw allow 8080/tcp
}

user_setup
docker_setup
openfaas_setup
firewall_setup
