#!/bin/bash

set -e

function required_variable() {
    if [ -z "${1}" ]; then
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
}

function mongo_setup() {
    required_variable "${mongo_version}"
    required_variable "${openfaas_instance_ip}"
    required_variable "${mongo_port}"

    docker image pull "mongo:${mongo_version}"

    docker run --name mongo --restart always -p ${mongo_port}:27017 -d "mongo:${mongo_version}"

    ufw allow from ${openfaas_instance_ip} to any port ${mongo_port} proto tcp
    ufw allow ssh
}

function create_redis_conf() {
    local redis_conf_file=$1

    if [ -f "$redis_conf_file" ]; then
        echo "The file $redis_conf_file already exists."
    else
        mkdir -p $(dirname $redis_conf_file)
        touch $redis_conf_file
        cat <<EOF >$redis_conf_file
bind 0.0.0.0 ::0
protected-mode no
port 6379
tcp-backlog 511
timeout 0
tcp-keepalive 300
daemonize no
pidfile /var/run/redis_6379.pid
loglevel notice
logfile ""
databases 16
always-show-logo no
set-proc-title yes
proc-title-template "{title} {listen-addr} {server-mode}"
locale-collate ""
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
rdb-del-sync-files no
dir ./
replica-serve-stale-data yes
replica-read-only yes
repl-diskless-sync yes
repl-diskless-sync-delay 5
repl-diskless-sync-max-replicas 0
repl-diskless-load disabled
repl-disable-tcp-nodelay no
replica-priority 100
acllog-max-len 128
lazyfree-lazy-eviction no
lazyfree-lazy-expire no
lazyfree-lazy-server-del no
replica-lazy-flush no
lazyfree-lazy-user-del no
lazyfree-lazy-user-flush no
oom-score-adj no
oom-score-adj-values 0 200 800
disable-thp yes
appendonly no
appendfilename "appendonly.aof"
appenddirname "appendonlydir"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
aof-use-rdb-preamble yes
aof-timestamp-enabled no
slowlog-log-slower-than 10000
slowlog-max-len 128
latency-monitor-threshold 0
notify-keyspace-events ""
hash-max-listpack-entries 512
hash-max-listpack-value 64
list-max-listpack-size -2
list-compress-depth 0
set-max-intset-entries 512
set-max-listpack-entries 128
set-max-listpack-value 64
zset-max-listpack-entries 128
zset-max-listpack-value 64
hll-sparse-max-bytes 3000
stream-node-max-bytes 4096
stream-node-max-entries 100
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
proto-max-bulk-len 512mb
hz 10
dynamic-hz yes
aof-rewrite-incremental-fsync yes
rdb-save-incremental-fsync yes
jemalloc-bg-thread yes
EOF
        echo "File $redis_conf_file created successfully."
    fi
}

function redis_setup() {
    required_variable ${redis_stack_version}
    required_variable ${redis_port}
    required_variable ${openfaas_instance_ip}

    local redis_conf_file="/etc/redis/redis.conf"

    create_redis_conf $redis_conf_file

    docker image pull redis/redis-stack-server:${redis_stack_version}

    docker run \
        --name redis \
        --restart always \
        -v $redis_conf_file:/redis-stack.conf \
        -p ${redis_port}:6379 \
        -d redis/redis-stack-server:${redis_stack_version}

    ufw allow from ${openfaas_instance_ip} to any port ${redis_port} proto tcp
    ufw allow ssh
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

    ufw allow 8080/tcp
    ufw allow ssh

    chmod +x install-openfaas.sh
    ./install-openfaas.sh >>install-openfaas.log 2>&1
}

function install_toolbox() {
    if [ ! command -v das-cli &> /dev/null ]; then
        bash -c "wget -O - http://45.77.4.33/apt-repo/setup.sh | bash"

        apt install das-cli
    else
        echo "Skipping setup installation, because das-cli is already installed."
    fi
}

function toolbox_setup() {
    install_toolbox

    cat <<EOF >/tmp/toolbox_config.txt
$redis_port
$mongo_port
admin
admin
EOF

    das-cli config set < /tmp/toolbox_config.txt

    das-cli server start
    das-cli faas start
}

function main() {
    required_variable ${environment_type}

    local LOG_FILE="/tmp/install.log"

    exec >"$LOG_FILE" 2>&1

    user_setup
    docker_setup
    firewall_setup
    install_toolbox

    if [ "$environment_type" == "redis" ]; then
        redis_setup
    elif [ "$environment_type" == "mongodb" ]; then
        mongo_setup
    elif [ "$environment_type" == "openfaas" ]; then
        openfaas_setup
    elif [ "$environment_type" == "toolbox" ]; then
        toolbox_setup
    else
        echo "Invalid environment type: '$environment_type'"
        exit 1
    fi

}

main
