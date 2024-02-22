#!/bin/bash
set -e

REDIS_CONF_FILE="/etc/redis/redis.conf"

function required_variable() {
    if [ -z "${1}" ]; then
        echo "The variable is not defined."
        exit 1
    fi
}

function check_variables() {
    required_variable ${USER_NAME}
    required_variable ${REDIS_STACK_VERSION}
    required_variable ${REDIS_PORT}
    required_variable ${OPENFAAS_INSTANCE_ID}
}

function user_setup() {
    adduser --disabled-password --gecos "" "${USER_NAME}"
    usermod -a -G ${USER_NAME} ${USER_NAME}
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

create_redis_conf() {

    if [ -f "$REDIS_CONF_FILE" ]; then
        echo "O arquivo $REDIS_CONF_FILE já existe."
    else
        cat <<EOF >$REDIS_CONF_FILE
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
        echo "File $REDIS_CONF_FILE created successfully."
    fi
}

function redis_setup() {
    create_redis_conf

    docker image pull redis/redis-stack-server:${REDIS_STACK_VERSION}

    docker run \
        --name redis \
        --restart always \
        -v $REDIS_CONF_FILE:/redis-stack.conf \
        --port ${REDIS_PORT}:6379 \
        -d redis/redis-stack-server:${REDIS_STACK_VERSION}
}

function firewall_setup() {
    if ! command -v ufw &>/dev/null; then
        apt-get update
        apt-get install ufw
    fi

    ufw -y enable
    ufw allow from ${OPENFAAS_INSTANCE_ID} to any port ${REDIS_PORT} proto tcp
    ufw allow ssh
}

LOG_FILE="/tmp/install-redis.log"

exec >"$LOG_FILE" 2>&1

check_variables
user_setup
docker_setup
redis_setup
firewall_setup
