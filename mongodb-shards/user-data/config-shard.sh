#!/bin/bash

exec >/tmp/config-shard.log 2>&1

function raise_command_not_found() {
  local cmd="$1"

  if ! command -v "$cmd" &> /dev/null; then
    echo "$cmd is required"
    exit 1
fi 
}

function install_mongodb() {
  if command -v mongod; then
    echo "Skipping mongodb installation because it's already installed."
    return 0
  fi

  wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
  echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
  apt update
  apt install -y mongodb-org
  systemctl start mongod
  systemctl enable mongod
  systemctl status mongod

  raise_command_not_found "mongod"
}

function setup() {
  local public_ip
  local mongodb_db_folder="/opt/shard/shardsvr-node"
  local mongodb_config="/opt/shard/mongod.conf"

  raise_command_not_found "curl"

  public_ip="$(curl ipinfo.io/ip)"

  mkdir -p $mongodb_db_folder

  cat <<EOF > $mongodb_config
systemLog:
  destination: file
  path: "/tmp/mongod.log"
  logAppend: true
storage:
  dbPath: "$mongodb_db_folder"
net:
  port: 28041
  bindIp: "$public_ip,localhost"
replication:
  replSetName: "shard_repl"
sharding:
  clusterRole: "shardsvr"
EOF

  mongod --config $mongodb_config &
}

install_mongodb
