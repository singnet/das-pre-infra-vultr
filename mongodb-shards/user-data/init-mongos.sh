#!/bin/bash

# GLOBAL VARIABLES
CONFIG_SET=""
SHARDS=""
PID_FILE="/run/terraform-shard-manager.pid"
MONGODB_CLUSTER_CONFIG="/opt/shard/mongod.conf"
MONGODB_DB_CLUSTER="/opt/shard/mongos-node"
MONGODB_LOGS="/tmp/mongod.log"

function cleanup() {
	if [ -f "$PID_FILE" ]; then
		rm -f "$PID_FILE"
	fi
}

function create_pid_file()  {
	local max_attempts=5

	for ((i=max_attempts; i>0;i--)); do
		if [ -f "$PID_FILE" ]; then
			echo "Script is already running with PID $(cat "$PID_FILE"). Waiting process to end..."
			sleep 1m
			continue
		fi

		echo $$ > "$PID_FILE"
		trap cleanup EXIT
		return 0
	done

	echo "Exiting due to waiting too long for the process to finish."
	exit 1
}

function cluster_initialized() {
  if [[ "$(mongosh --port 28041 --eval 'rs.status().ok')" == "1" ]]; then
    return 0
  fi

  return 1
}

function add_port_to_ips() {
  local ips_string="$1"
  local port="$2"
  local ips_with_ports=()

  IFS=',' read -r -a ip_array <<< "$ips_string"

  for ip in "${ip_array[@]}"; do
    ips_with_ports+=("${ip}:${port}")
  done

  IFS=','; echo "${ips_with_ports[*]}"
}

function setup() {
  local public_ip

  if cluster_initialized; then
    echo "The cluster has already been initialized. Skipping initialization..."
    exit 0
  fi

  public_ip="$(curl ipinfo.io/ip)"

  mkdir -p $MONGODB_DB_CLUSTER

  cat <<EOF > $MONGODB_CLUSTER_CONFIG
systemLog:
  destination: file
  path: "$MONGODB_LOGS"
  logAppend: true
net:
  port: 28041
  bindIp: "$public_ip,localhost"
sharding:
  configDB: "config_repl/$CONFIG_SET"
EOF

  mongos --port 28041 --config $MONGODB_CLUSTER_CONFIG &

  sleep 2m

  IFS=',' read -r -a shards <<< "$SHARDS"
  add_shards "${shards[@]}" 
}

function add_shards() {
  local shards=("$@")

  for shard in "${shards[@]}"; do
    echo "Adding shard: $shard"
    mongosh --port 28041 --eval "sh.addShard('$shard')"
  done
}

function parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      --config-set)
        CONFIG_SET=$(add_port_to_ips "$2" "28041")
        shift 2
        ;;
      --shards)
        SHARDS=$(add_port_to_ips "$2" "28041")
        shift 2
        ;;
      *)
        echo "Unknown parameter: $1"
        exit 1
        ;;
    esac
  done
}

create_pid_file
parse_args "$@"
setup