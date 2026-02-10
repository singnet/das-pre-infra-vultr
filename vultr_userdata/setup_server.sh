#!/bin/bash

# set -e

function docker_setup() {
    echo "Setting up Docker..."
    
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

function net-tools_setup(){
    echo "Setting up net-tools..."

    apt-get -y update
    apt install -y net-tools
}

function timezone_setup() {

    echo "Setting up BRT time zone..."

    DEFAULT_TIMEZONE=America/Sao_Paulo

    if ! command -v timedatectl &>/dev/null; then
        apt update
        apt install systemd-timesyncd
    fi

    timedatectl set-timezone $DEFAULT_TIMEZONE

}

function users_setup() {

    echo "Setting up the team users..."

    apt install jq -y

    USERS_FILE="./users_public_keys.json"

    jq -c '.[]' "$USERS_FILE" | while read -r user; do
        username=$(echo "$user" | jq -r '.username')
        pubkey=$(echo "$user"   | jq -r '.userPubKey')

        if ! id "$username" &>/dev/null; then
            adduser --disabled-password --gecos "" "$username"
        else
            echo "User $username already exists."
        fi

        user_home=$(eval echo "~$username")
        mkdir -p "$user_home/.ssh"
        echo "$pubkey" > "$user_home/.ssh/authorized_keys"

        chown -R "$username:$username" "$user_home/.ssh"
        chmod 700 "$user_home/.ssh"
        chmod 600 "$user_home/.ssh/authorized_keys"

        usermod -aG sudo $username
        usermod -aG docker $username

    done

}

function set_ssh_server_rules() {
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#\?UsePAM.*/UsePAM no/' /etc/ssh/sshd_config
}

function ssh_setup() {
    echo "Setting ssh server rules..."


    if [ -f /etc/ssh/sshd_config ]; then
        set_ssh_server_rules
    else
        apt install openssh-server -y

        set_ssh_server_rules

        systemctl restart ssh
    fi

}

function firewall_setup() {
    echo "Setting up UFW..."

    if ! command -v ufw &>/dev/null; then
        apt-get update
        apt-get install ufw
    fi

    ufw enable
    ufw allow ssh
}

function install_toolbox() {
    echo "Installing das-toolbox latest version..."

    if ! command -v das-cli &>/dev/null; then
        bash -c "wget -O - http://45.77.4.33/apt-repo/setup.sh | bash"

        apt install das-toolbox
    else
        echo "Skipping setup installation, because das-cli is already installed."
    fi
}

function main() {

    local LOG_FILE="/tmp/install.log"

    exec >"$LOG_FILE" 2>&1

    users_setup
    timezone_setup
    firewall_setup
    ssh_setup
    docker_setup
    net-tools_setup
    install_toolbox
}


main
