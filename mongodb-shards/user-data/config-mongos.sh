#!/bin/bash

# Global Variables
PID_FILE="/run/terraform-mongos-manager.pid"
CURRENT_SCRIPT_LOGS="/tmp/mongos-setup.log"

exec >$CURRENT_SCRIPT_LOGS 2>&1

function raise_command_not_found() {
  local cmd="$1"

  if ! command -v "$cmd" &> /dev/null; then
    echo "$cmd is required"
    exit 1
  fi
}

function enable_firewall() {
  if ! command -v ufw &>/dev/null; then
    apt-get update
    apt-get install ufw
  fi

  ufw enable
  ufw allow ssh
  ufw allow 28041
}

function cleanup() {
  if [ -f "$PID_FILE" ]; then
    rm -f "$PID_FILE"
  fi
}

function create_pid_file() {
  if [ -f "$PID_FILE" ]; then
    echo "Script is already running with PID $(cat "$PID_FILE"). Waiting process to end..."
    exit 1
  fi

  echo $$ > "$PID_FILE"
  trap cleanup EXIT
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

create_pid_file
install_mongodb
enable_firewall
